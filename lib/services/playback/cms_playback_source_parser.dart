import '../../models/playback/playback_source.dart';

class CmsPlaybackSourceParser {
  const CmsPlaybackSourceParser();

  List<PlaybackEpisode> parse({
    required String playFrom,
    required String playUrl,
    required Map<String, String> headers,
  }) {
    if (playUrl.trim().isEmpty) return const [];

    final labels = playFrom.split(r'$$$');
    final rawGroups = playUrl.split(r'$$$');
    final groups = <_CmsPlaybackGroup>[];

    for (var groupIndex = 0; groupIndex < rawGroups.length; groupIndex++) {
      final entries = _parseGroup(rawGroups[groupIndex]);
      if (entries.isEmpty) continue;
      final rawLabel =
          groupIndex < labels.length ? labels[groupIndex].trim() : '';
      groups.add(
        _CmsPlaybackGroup(
          originalIndex: groupIndex,
          label: rawLabel.isEmpty ? '线路 ${groupIndex + 1}' : rawLabel,
          entries: entries,
          containsHls: entries.any(
            (entry) => entry.url.toLowerCase().contains('.m3u8'),
          ),
        ),
      );
    }

    final buckets = <_EpisodeBucket>[];
    final hlsSourceIds = <String>{};

    for (final group in groups) {
      final sourceId = 'cms-${group.originalIndex}';
      if (group.containsHls) hlsSourceIds.add(sourceId);

      for (final entry in group.entries) {
        final bucket =
            _findBucket(buckets, entry) ?? _createBucket(buckets, entry);
        bucket.sources.add(
          PlaybackSource(
            id: sourceId,
            label: group.label,
            kind: PlaybackSourceKind.cms,
            headers: headers,
            variants: [
              PlaybackVariant(
                id: '$sourceId-${entry.ordinal + 1}',
                label: '原始',
                url: entry.url,
                kind: PlaybackVariantKind.original,
              ),
            ],
          ),
        );
      }
    }

    buckets.sort((left, right) => left.index.compareTo(right.index));
    return buckets.map((bucket) {
      bucket.sources.sort((left, right) {
        final leftHls = hlsSourceIds.contains(left.id);
        final rightHls = hlsSourceIds.contains(right.id);
        if (leftHls != rightHls) return leftHls ? -1 : 1;
        return _sourceIndex(left.id).compareTo(_sourceIndex(right.id));
      });
      return PlaybackEpisode(
        name: bucket.name.isEmpty ? '第 ${bucket.index} 集' : bucket.name,
        index: bucket.index,
        sources: bucket.sources,
      );
    }).toList(growable: false);
  }

  List<_CmsPlaybackEntry> _parseGroup(String rawGroup) {
    final entries = <_CmsPlaybackEntry>[];
    final records = rawGroup.split('#');
    for (var ordinal = 0; ordinal < records.length; ordinal++) {
      final record = records[ordinal].trim();
      final separator = record.indexOf(r'$');
      if (separator < 0) continue;
      final name = record.substring(0, separator).trim();
      final url = record.substring(separator + 1).trim();
      if (url.isEmpty) continue;
      entries.add(
        _CmsPlaybackEntry(
          ordinal: ordinal,
          name: name,
          url: url,
          episodeNumber: _episodeNumber(name),
          normalizedName: _normalizeTitle(name),
        ),
      );
    }
    return entries;
  }

  _EpisodeBucket? _findBucket(
    List<_EpisodeBucket> buckets,
    _CmsPlaybackEntry entry,
  ) {
    if (entry.episodeNumber != null) {
      for (final bucket in buckets) {
        if (bucket.episodeNumber == entry.episodeNumber) return bucket;
      }
    }
    if (entry.normalizedName.isNotEmpty) {
      for (final bucket in buckets) {
        if (bucket.normalizedName == entry.normalizedName) return bucket;
      }
    }
    for (final bucket in buckets) {
      if (bucket.ordinal == entry.ordinal && _titlesCompatible(bucket, entry)) {
        return bucket;
      }
    }
    return null;
  }

  _EpisodeBucket _createBucket(
    List<_EpisodeBucket> buckets,
    _CmsPlaybackEntry entry,
  ) {
    final bucket = _EpisodeBucket(
      ordinal: entry.ordinal,
      name: entry.name,
      normalizedName: entry.normalizedName,
      episodeNumber: entry.episodeNumber,
      index: entry.episodeNumber ?? buckets.length + 1,
    );
    buckets.add(bucket);
    return bucket;
  }

  bool _titlesCompatible(_EpisodeBucket bucket, _CmsPlaybackEntry entry) {
    if (bucket.name.isEmpty || entry.name.isEmpty) return true;
    if (bucket.episodeNumber != null || entry.episodeNumber != null) {
      return bucket.episodeNumber == entry.episodeNumber;
    }
    return bucket.normalizedName == entry.normalizedName;
  }

  static int? _episodeNumber(String value) {
    final match = RegExp(r'\d+').firstMatch(value);
    return match == null ? null : int.tryParse(match.group(0)!);
  }

  static String _normalizeTitle(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[\s\p{P}\p{S}]', unicode: true), '');
  }

  static int _sourceIndex(String sourceId) {
    return int.tryParse(sourceId.substring(sourceId.lastIndexOf('-') + 1)) ?? 0;
  }
}

class _CmsPlaybackGroup {
  const _CmsPlaybackGroup({
    required this.originalIndex,
    required this.label,
    required this.entries,
    required this.containsHls,
  });

  final int originalIndex;
  final String label;
  final List<_CmsPlaybackEntry> entries;
  final bool containsHls;
}

class _CmsPlaybackEntry {
  const _CmsPlaybackEntry({
    required this.ordinal,
    required this.name,
    required this.url,
    required this.episodeNumber,
    required this.normalizedName,
  });

  final int ordinal;
  final String name;
  final String url;
  final int? episodeNumber;
  final String normalizedName;
}

class _EpisodeBucket {
  _EpisodeBucket({
    required this.ordinal,
    required this.name,
    required this.normalizedName,
    required this.episodeNumber,
    required this.index,
  });

  final int ordinal;
  final String name;
  final String normalizedName;
  final int? episodeNumber;
  final int index;
  final List<PlaybackSource> sources = [];
}
