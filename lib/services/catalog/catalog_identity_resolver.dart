import '../../models/catalog/catalog_enums.dart';
import '../../models/catalog/catalog_values.dart';
import 'catalog_normalizer.dart';

typedef CatalogContentIdFactory = String Function();

class CatalogIdentityResolver {
  CatalogIdentityResolver({
    required Map<String, Object?> entryStore,
    required Map<String, Object?> referenceStore,
    CatalogContentIdFactory? createContentId,
    CatalogNormalizer normalizer = const CatalogNormalizer(),
  })  : _entryStore = entryStore,
        _referenceStore = referenceStore,
        _createContentId = createContentId ?? _defaultContentId,
        _normalizer = normalizer;

  static int _idSequence = 0;

  final Map<String, Object?> _entryStore;
  final Map<String, Object?> _referenceStore;
  final CatalogContentIdFactory _createContentId;
  final CatalogNormalizer _normalizer;

  CatalogContent upsert(CatalogContent candidate) {
    final contentId = _findByExternalRefs(candidate.externalRefs) ??
        _findByIdentity(candidate) ??
        _createUniqueContentId();
    final previous = _readContent(contentId);
    final resolved = _mergeContent(previous, candidate, contentId);
    _entryStore[contentId] = resolved.toMap();
    for (final ref in resolved.externalRefs) {
      _referenceStore[_externalKey(ref)] = <String, Object?>{
        'schemaVersion': 1,
        'kind': 'external',
        'contentId': contentId,
        'ref': ref.toMap(),
      };
    }
    return resolved;
  }

  String? _findByExternalRefs(Iterable<ExternalRef> refs) {
    for (final ref in refs) {
      final stored = _referenceStore[_externalKey(ref)];
      if (stored is! Map || stored['schemaVersion'] != 1) continue;
      final contentId = stored['contentId'];
      if (contentId is String && contentId.isNotEmpty) return contentId;
    }
    return null;
  }

  String? _findByIdentity(CatalogContent candidate) {
    if (candidate.year == null || candidate.format == CatalogFormat.unknown) {
      return null;
    }
    final normalizedTitle = _normalizedTitle(candidate);
    if (normalizedTitle.isEmpty) return null;
    final contentIds = _entryStore.keys.toList()..sort();
    for (final contentId in contentIds) {
      final existing = _readContent(contentId);
      if (existing == null) continue;
      if (_normalizedTitle(existing) == normalizedTitle &&
          existing.year == candidate.year &&
          existing.format == candidate.format) {
        return contentId;
      }
    }
    return null;
  }

  String _normalizedTitle(CatalogContent content) => _normalizer.normalizeTitle(
        content.normalizedTitle.isNotEmpty
            ? content.normalizedTitle
            : content.titles.primary,
      );

  CatalogContent? _readContent(String contentId) {
    final value = _entryStore[contentId];
    if (value is! Map) return null;
    return CatalogContent.fromMap(
      value.map((key, item) => MapEntry(key.toString(), item)),
    );
  }

  String _createUniqueContentId() {
    final base = _createContentId();
    if (!_entryStore.containsKey(base)) return base;
    var suffix = 1;
    while (_entryStore.containsKey('${base}_$suffix')) {
      suffix += 1;
    }
    return '${base}_$suffix';
  }

  static String _externalKey(ExternalRef ref) => 'external:${ref.storageKey}';

  static String _defaultContentId() {
    final micros =
        DateTime.now().toUtc().microsecondsSinceEpoch.toRadixString(36);
    final sequence = (_idSequence++).toRadixString(36);
    return 'catalog_$micros$sequence';
  }

  CatalogContent _mergeContent(
    CatalogContent? previous,
    CatalogContent candidate,
    String contentId,
  ) {
    final candidateIsNewer = previous == null ||
        (candidate.metadataUpdatedAt == null &&
            previous.metadataUpdatedAt == null) ||
        (candidate.metadataUpdatedAt != null &&
            (previous.metadataUpdatedAt == null ||
                !candidate.metadataUpdatedAt!
                    .isBefore(previous.metadataUpdatedAt!)));
    final externalRefs = <ExternalRef>{
      ...?previous?.externalRefs,
      ...candidate.externalRefs,
    }.toList()
      ..sort((left, right) => left.storageKey.compareTo(right.storageKey));
    final playableRefsByIdentity = <String, PlayableRef>{
      for (final ref in previous?.playableRefs ?? const <PlayableRef>[])
        ref.storageKey: ref,
    };
    for (final ref in candidate.playableRefs) {
      if (!playableRefsByIdentity.containsKey(ref.storageKey) ||
          candidateIsNewer) {
        playableRefsByIdentity[ref.storageKey] = ref;
      }
    }
    final playableRefs = playableRefsByIdentity.values.toList()
      ..sort((left, right) => left.storageKey.compareTo(right.storageKey));
    final genres = <String>{
      ...?previous?.genres,
      ...candidate.genres,
    };
    final ratings = <String, CatalogRating>{
      ...?previous?.ratings,
    };
    for (final entry in candidate.ratings.entries) {
      if (!ratings.containsKey(entry.key) || candidateIsNewer) {
        ratings[entry.key] = entry.value;
      }
    }
    final previousTitles = previous?.titles;
    final titles = CatalogTitles(
      primary: _mergeText(
            previousTitles?.primary,
            candidate.titles.primary,
            candidateIsNewer,
          ) ??
          '',
      original: _mergeText(
        previousTitles?.original,
        candidate.titles.original,
        candidateIsNewer,
      ),
      english: _mergeText(
        previousTitles?.english,
        candidate.titles.english,
        candidateIsNewer,
      ),
      chinese: _mergeText(
        previousTitles?.chinese,
        candidate.titles.chinese,
        candidateIsNewer,
      ),
      aliases: _stableDistinctStrings([
        ...?previousTitles?.aliases,
        ...candidate.titles.aliases,
      ]),
    );
    final previousNormalized = previous?.normalizedTitle ?? '';
    final normalizedTitle = _mergeText(
          previousNormalized,
          _normalizedTitle(candidate),
          candidateIsNewer,
        ) ??
        '';
    return CatalogContent(
      contentId: contentId,
      titles: titles,
      normalizedTitle: normalizedTitle,
      year: _mergeNullable(
        previous?.year,
        candidate.year,
        candidateIsNewer,
      ),
      season: previous == null ||
              previous.season == CatalogSeason.unknown ||
              (candidate.season != CatalogSeason.unknown && candidateIsNewer)
          ? candidate.season
          : previous.season,
      format: previous == null ||
              previous.format == CatalogFormat.unknown ||
              (candidate.format != CatalogFormat.unknown && candidateIsNewer)
          ? candidate.format
          : previous.format,
      status: previous == null ||
              previous.status == CatalogStatus.unknown ||
              (candidate.status != CatalogStatus.unknown && candidateIsNewer)
          ? candidate.status
          : previous.status,
      region: previous == null ||
              previous.region == CatalogRegion.unknown ||
              (candidate.region != CatalogRegion.unknown && candidateIsNewer)
          ? candidate.region
          : previous.region,
      genres: genres,
      ratings: ratings,
      synopsis: _mergeText(
        previous?.synopsis,
        candidate.synopsis,
        candidateIsNewer,
      ),
      coverUrl: _mergeText(
        previous?.coverUrl,
        candidate.coverUrl,
        candidateIsNewer,
      ),
      metadataUpdatedAt: _latest(
        previous?.metadataUpdatedAt,
        candidate.metadataUpdatedAt,
      ),
      externalRefs: externalRefs,
      playableRefs: playableRefs,
    );
  }

  static String? _mergeText(
    String? previous,
    String? candidate,
    bool candidateIsNewer,
  ) {
    final oldValue = _nonEmpty(previous);
    final newValue = _nonEmpty(candidate);
    if (oldValue == null) return newValue;
    if (newValue == null) return oldValue;
    return candidateIsNewer ? newValue : oldValue;
  }

  static String? _nonEmpty(String? value) =>
      value == null || value.trim().isEmpty ? null : value;

  static T? _mergeNullable<T>(
    T? previous,
    T? candidate,
    bool candidateIsNewer,
  ) {
    if (previous == null) return candidate;
    if (candidate == null) return previous;
    return candidateIsNewer ? candidate : previous;
  }

  static List<String> _stableDistinctStrings(Iterable<String> values) {
    final seen = <String>{};
    return values.where((value) => seen.add(value)).toList(growable: false);
  }

  static DateTime? _latest(DateTime? previous, DateTime? candidate) {
    if (previous == null) return candidate;
    if (candidate == null || candidate.isBefore(previous)) return previous;
    return candidate;
  }
}
