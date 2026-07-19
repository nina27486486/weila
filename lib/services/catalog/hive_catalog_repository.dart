import '../../models/catalog/catalog_enums.dart';
import '../../models/catalog/catalog_values.dart';
import 'catalog_cache_policy.dart';
import 'catalog_identity_resolver.dart';
import 'catalog_normalizer.dart';
import 'catalog_repository.dart';

const catalogEntriesStoreName = 'catalog_entries_v1';
const catalogReferencesStoreName = 'catalog_refs_v1';
const catalogQueryCacheStoreName = 'catalog_query_cache_v1';

typedef CatalogClock = DateTime Function();
typedef CatalogPageLoader = Future<CatalogPage> Function(CatalogQuery query);
typedef CatalogStorePersistence = Future<void> Function();

class HiveCatalogRepository implements CatalogRepository {
  HiveCatalogRepository({
    required Map<String, Object?> entryStore,
    required Map<String, Object?> referenceStore,
    required Map<String, Object?> queryCacheStore,
    CatalogPageLoader? loadPage,
    CatalogStorePersistence? persistStores,
    CatalogClock? now,
    CatalogContentIdFactory? createContentId,
  })  : _entryStore = entryStore,
        _referenceStore = referenceStore,
        _queryCacheStore = queryCacheStore,
        _loadPage = loadPage,
        _persistStores = persistStores,
        _now = now ?? DateTime.now,
        _identityResolver = CatalogIdentityResolver(
          entryStore: entryStore,
          referenceStore: referenceStore,
          createContentId: createContentId,
        );

  final Map<String, Object?> _entryStore;
  final Map<String, Object?> _referenceStore;
  final Map<String, Object?> _queryCacheStore;
  final CatalogPageLoader? _loadPage;
  final CatalogStorePersistence? _persistStores;
  final CatalogClock _now;
  final CatalogIdentityResolver _identityResolver;
  final CatalogNormalizer _normalizer = const CatalogNormalizer();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
  }

  @override
  Future<CatalogPage> query(
    CatalogQuery query, {
    bool forceRefresh = false,
  }) async {
    await initialize();
    final now = _now().toUtc();
    final requiresLivePlayableFilter = _loadPage == null &&
        (query.mode == CatalogMode.playable || query.providerId != null);
    if (!forceRefresh && !requiresLivePlayableFilter) {
      final cached = _readCache(query.cacheKey);
      if (cached != null && now.isBefore(cached.expiresAt)) {
        return _hydratePagePlayableRefs(cached.page, now);
      }
    }

    final loader = _loadPage;
    final CatalogPage page;
    if (loader == null) {
      page = _queryLocal(query, now);
    } else {
      late final CatalogPage loaded;
      try {
        loaded = await loader(query);
      } catch (_) {
        final stale = _readCache(query.cacheKey);
        if (stale == null) rethrow;
        final hydrated = _hydratePagePlayableRefs(stale.page, now);
        return CatalogPage(
          items: hydrated.items,
          nextCursor: hydrated.nextCursor,
          coverage: hydrated.coverage,
          warning: '目录更新失败，正在显示旧缓存结果。',
        );
      }
      final items = <CatalogContent>[];
      for (final candidate in loaded.items) {
        final resolved = _identityResolver.upsert(candidate);
        _syncPlayableRefs(
          resolved.contentId,
          candidate.playableRefs,
          now,
        );
        items.add(_hydratePlayableRefs(resolved, now));
      }
      page = CatalogPage(
        items: List<CatalogContent>.unmodifiable(items),
        nextCursor: loaded.nextCursor,
        coverage: loaded.coverage,
      );
    }
    final ttl = query.mode == CatalogMode.playable || query.providerId != null
        ? catalogCmsListTtl
        : catalogDiscoveryMetadataTtl;
    _queryCacheStore[query.cacheKey] = CatalogCacheState(
      page: page,
      storedAt: now,
      expiresAt: now.add(ttl),
    ).toMap();
    await _persistStores?.call();
    return page;
  }

  CatalogPage _queryLocal(CatalogQuery query, DateTime now) {
    final items = <CatalogContent>[];
    for (final value in _entryStore.values) {
      if (value is! Map || value['schemaVersion'] != 1) continue;
      final content = CatalogContent.fromMap(
        value.map((mapKey, item) => MapEntry(mapKey.toString(), item)),
      );
      final hydrated = _hydratePlayableRefs(content, now);
      if (!_matchesLocal(hydrated, query, now)) continue;
      items.add(hydrated);
    }
    items.sort((left, right) => _compareContent(left, right, query.sort));
    final parsedCursor = int.tryParse(query.cursor ?? '') ?? 0;
    final start = parsedCursor.clamp(0, items.length);
    final limit = query.limit > 0 ? query.limit : 1;
    final requestedEnd = start + limit;
    final end = requestedEnd < items.length ? requestedEnd : items.length;
    final nextCursor = end < items.length ? end.toString() : null;
    return CatalogPage(
      items: items.sublist(start, end),
      nextCursor: nextCursor,
      coverage: CatalogQueryCoverage(
        modes: {query.mode},
        dimensions: _coverageDimensions(query),
        complete: query.mode != CatalogMode.unknown && nextCursor == null,
      ),
    );
  }

  Set<String> _coverageDimensions(CatalogQuery query) {
    final dimensions = <String>{'sort', 'limit'};
    if (query.mode == CatalogMode.playable) dimensions.add('playable');
    if (_normalizer.normalizeTitle(query.text ?? '').isNotEmpty) {
      dimensions.add('text');
    }
    if (query.genres.isNotEmpty) dimensions.add('genres');
    if (query.year != null) dimensions.add('year');
    if (query.season != null) dimensions.add('season');
    if (query.format != null) dimensions.add('format');
    if (query.status != null) dimensions.add('status');
    if (query.region != null) dimensions.add('region');
    if (query.minimumScore != null) dimensions.add('minimumScore');
    if (query.providerId != null) dimensions.add('providerId');
    if (query.updatedWithin != null) dimensions.add('updatedWithin');
    if (query.cursor != null) dimensions.add('cursor');
    return dimensions;
  }

  bool _matchesLocal(
    CatalogContent content,
    CatalogQuery query,
    DateTime now,
  ) {
    if (query.mode == CatalogMode.playable && content.playableRefs.isEmpty) {
      return false;
    }
    final search = _normalizer.normalizeTitle(query.text ?? '');
    if (search.isNotEmpty) {
      final titles = <String>[
        content.normalizedTitle,
        content.titles.primary,
        if (content.titles.original != null) content.titles.original!,
        if (content.titles.english != null) content.titles.english!,
        if (content.titles.chinese != null) content.titles.chinese!,
        ...content.titles.aliases,
      ];
      final hasTitle = titles.any(
        (title) => _normalizer.normalizeTitle(title).contains(search),
      );
      if (!hasTitle) return false;
    }
    if (!_normalizer.matchesAllGenres(
      contentGenres: content.genres,
      selectedGenres: query.genres,
    )) {
      return false;
    }
    if (query.year != null && content.year != query.year) return false;
    if (query.season != null && content.season != query.season) return false;
    if (query.format != null && content.format != query.format) return false;
    if (query.status != null && content.status != query.status) return false;
    if (query.region != null && content.region != query.region) return false;
    final minimumScore = query.minimumScore;
    if (minimumScore != null) {
      final scores = content.ratings.values
          .map((rating) => rating.score)
          .whereType<double>();
      final qualifies = scores.any((score) => score >= minimumScore);
      if (!qualifies) return false;
    }
    final providerId = query.providerId;
    if (providerId != null &&
        !content.playableRefs.any((ref) => ref.providerId == providerId)) {
      return false;
    }
    final updatedWithin = query.updatedWithin;
    if (updatedWithin != null) {
      final updatedAt = content.metadataUpdatedAt;
      if (updatedAt == null ||
          updatedAt.toUtc().isBefore(now.subtract(updatedWithin))) {
        return false;
      }
    }
    return true;
  }

  int _compareContent(
    CatalogContent left,
    CatalogContent right,
    CatalogSort sort,
  ) {
    final compared = switch (sort) {
      CatalogSort.title => _normalizer
          .normalizeTitle(left.titles.primary)
          .compareTo(_normalizer.normalizeTitle(right.titles.primary)),
      CatalogSort.rating => _compareNullableDoubleDesc(
          _bestScore(left),
          _bestScore(right),
        ),
      CatalogSort.popularity => _compareNullableIntDesc(
          _mostVotes(left),
          _mostVotes(right),
        ),
      CatalogSort.updatedAt => _compareNullableDateDesc(
          left.metadataUpdatedAt,
          right.metadataUpdatedAt,
        ),
      CatalogSort.releaseDate => _compareNullableIntDesc(left.year, right.year),
      CatalogSort.relevance || CatalogSort.unknown => 0,
    };
    return compared != 0 ? compared : left.contentId.compareTo(right.contentId);
  }

  static double? _bestScore(CatalogContent content) {
    double? result;
    for (final rating in content.ratings.values) {
      final score = rating.score;
      if (score != null && (result == null || score > result)) result = score;
    }
    return result;
  }

  static int? _mostVotes(CatalogContent content) {
    int? result;
    for (final rating in content.ratings.values) {
      final votes = rating.votes;
      if (votes != null && (result == null || votes > result)) result = votes;
    }
    return result;
  }

  static int _compareNullableDoubleDesc(double? left, double? right) {
    if (left == null) return right == null ? 0 : 1;
    if (right == null) return -1;
    return right.compareTo(left);
  }

  static int _compareNullableIntDesc(int? left, int? right) {
    if (left == null) return right == null ? 0 : 1;
    if (right == null) return -1;
    return right.compareTo(left);
  }

  static int _compareNullableDateDesc(DateTime? left, DateTime? right) {
    if (left == null) return right == null ? 0 : 1;
    if (right == null) return -1;
    return right.compareTo(left);
  }

  CatalogCacheState? _readCache(String key) {
    final value = _queryCacheStore[key];
    if (value is! Map || value['schemaVersion'] != 1) return null;
    return CatalogCacheState.fromMap(
      value.map((mapKey, item) => MapEntry(mapKey.toString(), item)),
    );
  }

  @override
  Future<CatalogContent?> getById(String contentId) async {
    await initialize();
    final value = _entryStore[contentId];
    if (value is! Map || value['schemaVersion'] != 1) return null;
    final content = CatalogContent.fromMap(
      value.map((mapKey, item) => MapEntry(mapKey.toString(), item)),
    );
    return _hydratePlayableRefs(content, _now().toUtc());
  }

  @override
  Future<List<PlayableMatch>> findPlayable(String contentId) async {
    await initialize();
    return _readPlayableMatches(contentId, _now().toUtc());
  }

  List<PlayableMatch> _readPlayableMatches(
    String contentId,
    DateTime now,
  ) {
    final matches = <String, PlayableMatch>{};
    for (final value in _referenceStore.values) {
      if (value is! Map ||
          value['schemaVersion'] != 1 ||
          value['kind'] != 'playable' ||
          value['contentId'] != contentId ||
          value['match'] is! Map) {
        continue;
      }
      final expiresAt = DateTime.tryParse(
        value['expiresAt']?.toString() ?? '',
      )?.toUtc();
      if (expiresAt == null || !now.isBefore(expiresAt)) continue;
      final match = PlayableMatch.fromMap(
        (value['match'] as Map).map(
          (mapKey, item) => MapEntry(mapKey.toString(), item),
        ),
      );
      final previous = matches[match.ref.storageKey];
      if (previous == null ||
          (match.confirmed && !previous.confirmed) ||
          match.confidence > previous.confidence) {
        matches[match.ref.storageKey] = match;
      }
    }
    final result = matches.values.toList()
      ..sort((left, right) {
        if (left.confirmed != right.confirmed) {
          return left.confirmed ? -1 : 1;
        }
        final confidence = right.confidence.compareTo(left.confidence);
        if (confidence != 0) return confidence;
        return left.ref.storageKey.compareTo(right.ref.storageKey);
      });
    return result;
  }

  CatalogContent _hydratePlayableRefs(
    CatalogContent content,
    DateTime now,
  ) {
    final refs = _readPlayableMatches(content.contentId, now)
        .map((match) => match.ref)
        .toList()
      ..sort((left, right) => left.storageKey.compareTo(right.storageKey));
    return CatalogContent(
      contentId: content.contentId,
      titles: content.titles,
      normalizedTitle: content.normalizedTitle,
      year: content.year,
      season: content.season,
      format: content.format,
      status: content.status,
      region: content.region,
      genres: content.genres,
      ratings: content.ratings,
      synopsis: content.synopsis,
      coverUrl: content.coverUrl,
      metadataUpdatedAt: content.metadataUpdatedAt,
      externalRefs: content.externalRefs,
      playableRefs: List<PlayableRef>.unmodifiable(refs),
    );
  }

  CatalogPage _hydratePagePlayableRefs(CatalogPage page, DateTime now) =>
      CatalogPage(
        items: page.items
            .map((content) => _hydratePlayableRefs(content, now))
            .toList(growable: false),
        nextCursor: page.nextCursor,
        coverage: page.coverage,
        warning: page.warning,
      );

  void _syncPlayableRefs(
    String contentId,
    Iterable<PlayableRef> refs,
    DateTime now,
  ) {
    for (final ref in refs) {
      _referenceStore[_playableKey(contentId, ref)] = {
        'schemaVersion': 1,
        'kind': 'playable',
        'contentId': contentId,
        'match': PlayableMatch(
          ref: ref,
          confidence: 1,
          reason: 'catalog-loader',
        ).toMap(),
        'expiresAt': now.add(catalogPlayableBindingTtl).toIso8601String(),
      };
    }
  }

  @override
  Future<void> confirmPlayable(String contentId, PlayableRef ref) async {
    await initialize();
    final now = _now().toUtc();
    _referenceStore[_playableKey(contentId, ref)] = {
      'schemaVersion': 1,
      'kind': 'playable',
      'contentId': contentId,
      'match': PlayableMatch(
        ref: ref,
        confidence: 1,
        confirmed: true,
        reason: 'confirmed',
      ).toMap(),
      'confirmedAt': now.toIso8601String(),
      'expiresAt': now.add(catalogPlayableBindingTtl).toIso8601String(),
    };
    _queryCacheStore.clear();
    await _persistStores?.call();
  }

  static String _playableKey(String contentId, PlayableRef ref) =>
      'playable:${Uri.encodeComponent(contentId)}:${ref.storageKey}';
}
