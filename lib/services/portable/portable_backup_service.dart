import '../../models/collect_item.dart';
import '../../models/history_item.dart';
import '../../models/track_item.dart';
import 'weila_portable_backup.dart';

/// 便携备份所需的最小库访问能力；StorageService 实现之，
/// 测试用内存实现替换。
abstract interface class PortableLibraryStore {
  List<CollectItem> getFavorites();

  List<TrackItem> getFollowing();

  List<HistoryItem> getHistory();

  Future<void> putFavorite(CollectItem item);

  Future<void> removeFavorite(String animeUrl);

  Future<void> putFollowing(TrackItem item);

  Future<void> removeFollowing(String animeUrl);

  Future<void> putHistory(HistoryItem item);

  Future<void> removeHistory(String animeUrl);

  Object? readSetting(String key);

  Future<void> writeSetting(String key, Object value);
}

class PortableImportReport {
  const PortableImportReport({
    required this.favoritesApplied,
    required this.followingApplied,
    required this.historyApplied,
    required this.settingsApplied,
  });

  final int favoritesApplied;
  final int followingApplied;
  final int historyApplied;
  final int settingsApplied;

  int get totalEntries => favoritesApplied + followingApplied + historyApplied;
}

/// 采集/合并/写回编排。导入是事务式的：任何解析或校验失败都不会
/// 触碰本地数据（[WeilaPortableBackupV1.decodeJson] 在写回前完成）。
class PortableBackupService {
  PortableBackupService({
    required PortableLibraryStore store,
    String Function()? appVersion,
  })  : _store = store,
        _appVersion = appVersion ?? (() => 'unknown');

  static const int maximumBackupBytes = 32 * 1024 * 1024;

  final PortableLibraryStore _store;
  final String Function() _appVersion;

  Future<String> exportJson() async {
    final backup = WeilaPortableBackupV1(
      exportedAtUtc: DateTime.now().toUtc(),
      appVersion: _appVersion(),
      favorites: _store.getFavorites().map(_favoriteToMap).toList(),
      history: _store.getHistory().map(_historyToMap).toList(),
      following: _store.getFollowing().map(_followingToMap).toList(),
      safeSettings: _collectSafeSettings(),
    );
    return backup.encodeJson();
  }

  Future<PortableImportReport> importJson(String source) async {
    final backup = WeilaPortableBackupV1.decodeJson(source);

    var favorites = 0;
    var following = 0;
    var history = 0;
    final settings = <String>[];

    // 同一备份内先按身份去重，避免自相残杀的写回。
    final favoritesByIdentity = <String, Map<String, Object?>>{};
    for (final entry in backup.favorites) {
      final key = portableEntryIdentity(entry);
      favoritesByIdentity[key] = favoritesByIdentity.containsKey(key)
          ? mergeByTimestamp(favoritesByIdentity[key]!, entry, 'collectedAt')
          : entry;
    }
    final followingByIdentity = <String, Map<String, Object?>>{};
    for (final entry in backup.following) {
      final key = portableEntryIdentity(entry);
      followingByIdentity[key] = followingByIdentity.containsKey(key)
          ? mergeByTimestamp(followingByIdentity[key]!, entry, 'trackedAt')
          : entry;
    }
    final historyByIdentity = <String, Map<String, Object?>>{};
    for (final entry in backup.history) {
      final key = portableEntryIdentity(entry);
      historyByIdentity[key] = historyByIdentity.containsKey(key)
          ? mergeHistoryEntry(historyByIdentity[key]!, entry)
          : entry;
    }

    for (final entry in favoritesByIdentity.values) {
      await _mergeFavorite(entry);
      favorites++;
    }
    for (final entry in followingByIdentity.values) {
      await _mergeFollowing(entry);
      following++;
    }
    for (final entry in historyByIdentity.values) {
      await _mergeHistory(entry);
      history++;
    }
    for (final setting in backup.safeSettings.entries) {
      final value = setting.value;
      if (value == null) continue;
      await _store.writeSetting(setting.key, value);
      settings.add(setting.key);
    }

    return PortableImportReport(
      favoritesApplied: favorites,
      followingApplied: following,
      historyApplied: history,
      settingsApplied: settings.length,
    );
  }

  // ─── 采集（白名单字段） ──────────────────────────────────────────────────

  Map<String, Object?> _favoriteToMap(CollectItem item) => {
        'contentId': item.contentId,
        'animeUrl': item.animeUrl,
        'animeName': item.animeName,
        'sourcePlugin': item.sourcePlugin,
        'cover': item.cover,
        'description': item.description,
        'collectedAt': item.collectedAt.toUtc().toIso8601String(),
      };

  Map<String, Object?> _historyToMap(HistoryItem item) => {
        'contentId': item.contentId,
        'animeUrl': item.animeUrl,
        'animeName': item.animeName,
        'episodeName': item.episodeName,
        'episodeUrl': item.episodeUrl,
        'sourcePlugin': item.sourcePlugin,
        'cover': item.cover,
        'positionMs': item.position.inMilliseconds,
        'durationMs': item.duration.inMilliseconds,
        'watchedAt': item.watchedAt.toUtc().toIso8601String(),
      };

  Map<String, Object?> _followingToMap(TrackItem item) => {
        'contentId': item.contentId,
        'animeUrl': item.animeUrl,
        'animeName': item.animeName,
        'sourcePlugin': item.sourcePlugin,
        'cover': item.cover,
        'status': item.status,
        'totalEpisodes': item.totalEpisodes,
        'watchedEpisodes': item.watchedEpisodes,
        'trackedAt': item.trackedAt.toUtc().toIso8601String(),
      };

  Map<String, Object?> _collectSafeSettings() {
    final result = <String, Object?>{};
    final isDarkMode = _store.readSetting('isDarkMode');
    if (isDarkMode is bool) result['isDarkMode'] = isDarkMode;
    final showAdultCatalog = _store.readSetting('catalog_include_adult');
    if (showAdultCatalog is bool) {
      result['showAdultCatalog'] = showAdultCatalog;
    }
    return result;
  }

  // ─── 合并写回 ───────────────────────────────────────────────────────────

  Future<void> _mergeFavorite(Map<String, Object?> entry) async {
    final identity = portableEntryIdentity(entry);
    for (final existing in _store.getFavorites()) {
      if (portableEntryIdentity(_favoriteToMap(existing)) == identity) {
        final merged = mergeByTimestamp(
          _favoriteToMap(existing),
          entry,
          'collectedAt',
        );
        await _store.removeFavorite(existing.animeUrl);
        await _store.putFavorite(_favoriteFromMap(merged));
        return;
      }
    }
    await _store.putFavorite(_favoriteFromMap(entry));
  }

  Future<void> _mergeFollowing(Map<String, Object?> entry) async {
    final identity = portableEntryIdentity(entry);
    for (final existing in _store.getFollowing()) {
      if (portableEntryIdentity(_followingToMap(existing)) == identity) {
        final merged = mergeByTimestamp(
          _followingToMap(existing),
          entry,
          'trackedAt',
        );
        // 追番进度取较大值（跨端接力看番）。
        final existingWatched = existing.watchedEpisodes;
        final mergedWatched = (merged['watchedEpisodes'] as int?) ?? 0;
        if (mergedWatched < existingWatched) {
          merged['watchedEpisodes'] = existingWatched;
        }
        await _store.removeFollowing(existing.animeUrl);
        await _store.putFollowing(_followingFromMap(merged));
        return;
      }
    }
    await _store.putFollowing(_followingFromMap(entry));
  }

  Future<void> _mergeHistory(Map<String, Object?> entry) async {
    final identity = portableEntryIdentity(entry);
    for (final existing in _store.getHistory()) {
      if (portableEntryIdentity(_historyToMap(existing)) == identity) {
        final merged = mergeHistoryEntry(_historyToMap(existing), entry);
        await _store.removeHistory(existing.animeUrl);
        await _store.putHistory(_historyFromMap(merged));
        return;
      }
    }
    await _store.putHistory(_historyFromMap(entry));
  }

  CollectItem _favoriteFromMap(Map<String, Object?> map) => CollectItem(
        animeName: map['animeName'] as String,
        animeUrl: map['animeUrl'] as String,
        sourcePlugin: map['sourcePlugin'] as String,
        cover: map['cover'] as String?,
        description: map['description'] as String?,
        contentId: map['contentId'] as String?,
        collectedAt: DateTime.parse(map['collectedAt'] as String),
      );

  TrackItem _followingFromMap(Map<String, Object?> map) => TrackItem(
        animeName: map['animeName'] as String,
        animeUrl: map['animeUrl'] as String,
        sourcePlugin: map['sourcePlugin'] as String,
        cover: map['cover'] as String?,
        status: map['status'] as String?,
        totalEpisodes: (map['totalEpisodes'] as int?) ?? 0,
        watchedEpisodes: (map['watchedEpisodes'] as int?) ?? 0,
        trackedAt: DateTime.parse(map['trackedAt'] as String),
      );

  HistoryItem _historyFromMap(Map<String, Object?> map) => HistoryItem(
        animeName: map['animeName'] as String,
        animeUrl: map['animeUrl'] as String,
        episodeName: map['episodeName'] as String,
        episodeUrl: map['episodeUrl'] as String,
        sourcePlugin: map['sourcePlugin'] as String,
        cover: map['cover'] as String?,
        position: Duration(milliseconds: (map['positionMs'] as int?) ?? 0),
        duration: Duration(milliseconds: (map['durationMs'] as int?) ?? 0),
        contentId: map['contentId'] as String?,
        episodeId: null,
        watchedAt: DateTime.parse(map['watchedAt'] as String),
      );
}
