import '../../models/anime.dart';
import '../../models/download_item.dart';
import '../../models/history_item.dart';
import '../plugin/plugin_service.dart';

typedef AnimeDetailLoader = Future<Map<String, dynamic>?> Function(Anime anime);

class MediaMetadataService {
  factory MediaMetadataService() => _instance;

  MediaMetadataService.withLoader(AnimeDetailLoader loader) : _loader = loader;

  static final MediaMetadataService _instance =
      MediaMetadataService.withLoader(PluginService().getDetail);

  final AnimeDetailLoader _loader;
  final Map<String, Future<_ResolvedMetadata?>> _lookups = {};

  Future<bool> hydrateHistoryItem(HistoryItem item) async {
    final changed = await _hydrate(
      animeName: item.animeName,
      animeUrl: item.animeUrl,
      episodeName: item.episodeName,
      sourcePlugin: item.sourcePlugin,
      coverUrl: item.cover,
      onName: (value) => item.animeName = value,
      onCover: (value) => item.cover = value,
    );
    if (changed && item.isInBox) await item.save();
    return changed;
  }

  Future<bool> hydrateDownloadItem(DownloadItem item) async {
    final changed = await _hydrate(
      animeName: item.animeName,
      animeUrl: item.animeUrl,
      episodeName: item.episodeName,
      sourcePlugin: item.sourcePlugin,
      coverUrl: item.cover,
      onName: (value) => item.animeName = value,
      onCover: (value) => item.cover = value,
    );
    if (changed && item.isInBox) await item.save();
    return changed;
  }

  Future<int> hydrateHistory(Iterable<HistoryItem> items) {
    return _hydrateInBatches(items, hydrateHistoryItem);
  }

  Future<int> hydrateDownloads(Iterable<DownloadItem> items) {
    return _hydrateInBatches(items, hydrateDownloadItem);
  }

  Future<int> _hydrateInBatches<T>(
    Iterable<T> values,
    Future<bool> Function(T value) hydrate,
  ) async {
    final pending = values.toList(growable: false);
    var changed = 0;
    for (var start = 0; start < pending.length; start += 4) {
      final results = await Future.wait(
        pending.skip(start).take(4).map(hydrate),
      );
      changed += results.where((value) => value).length;
    }
    return changed;
  }

  Future<bool> _hydrate({
    required String animeName,
    required String animeUrl,
    required String episodeName,
    required String sourcePlugin,
    required String? coverUrl,
    required void Function(String value) onName,
    required void Function(String value) onCover,
  }) async {
    final titleNeedsRepair = _isMissingAnimeTitle(animeName, episodeName);
    final coverNeedsRepair = coverUrl == null || coverUrl.trim().isEmpty;
    if (!titleNeedsRepair && !coverNeedsRepair) return false;
    if (animeUrl.trim().isEmpty || sourcePlugin.trim().isEmpty) return false;

    final cacheKey = '$sourcePlugin|$animeUrl';
    final metadata = await _lookups.putIfAbsent(
      cacheKey,
      () => _loadMetadata(
        animeName: animeName,
        animeUrl: animeUrl,
        sourcePlugin: sourcePlugin,
      ),
    );
    if (metadata == null) {
      _lookups.remove(cacheKey);
      return false;
    }

    var changed = false;
    if (titleNeedsRepair && metadata.name.isNotEmpty) {
      onName(metadata.name);
      changed = true;
    }
    final resolvedCover = metadata.coverUrl;
    if (coverNeedsRepair && resolvedCover != null && resolvedCover.isNotEmpty) {
      onCover(resolvedCover);
      changed = true;
    }
    return changed;
  }

  Future<_ResolvedMetadata?> _loadMetadata({
    required String animeName,
    required String animeUrl,
    required String sourcePlugin,
  }) async {
    try {
      final detail = await _loader(
        Anime(
          name: animeName,
          url: animeUrl,
          sourcePlugin: sourcePlugin,
        ),
      );
      if (detail == null) return null;
      final name =
          (detail['name'] ?? detail['name_cn'])?.toString().trim() ?? '';
      final cover = detail['cover']?.toString().trim();
      if (name.isEmpty && (cover == null || cover.isEmpty)) return null;
      return _ResolvedMetadata(name: name, coverUrl: cover);
    } catch (_) {
      return null;
    }
  }

  static bool _isMissingAnimeTitle(String animeName, String episodeName) {
    final title = animeName.trim();
    if (title.isEmpty || title == episodeName.trim()) return true;
    return RegExp(
      r'^(?:第\s*[0-9０-９一二三四五六七八九十百]+\s*[集话話]|'
      r'ep(?:isode)?\s*\d+|hd中字|中字|正片|全集)(?:\s.*)?$',
      caseSensitive: false,
    ).hasMatch(title);
  }
}

class _ResolvedMetadata {
  const _ResolvedMetadata({required this.name, required this.coverUrl});

  final String name;
  final String? coverUrl;
}
