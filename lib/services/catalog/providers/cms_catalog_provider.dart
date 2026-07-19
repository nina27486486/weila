import '../../../models/catalog/catalog_enums.dart';
import '../../../models/catalog/catalog_values.dart';
import '../../../models/plugin.dart';
import '../../../models/plugin_catalog.dart';
import '../../http/http_client.dart';
import '../../playback/cms_playback_source_parser.dart';
import '../catalog_normalizer.dart';
import 'catalog_provider.dart';

typedef CmsCatalogClock = DateTime Function();

class CmsCatalogProvider implements CatalogProvider {
  CmsCatalogProvider({
    required this.plugin,
    CatalogGetJson? getJson,
    CmsCatalogClock? now,
    CmsPlaybackSourceParser parser = const CmsPlaybackSourceParser(),
  })  : _getJson = getJson ?? _defaultGetJson,
        _now = now ?? DateTime.now,
        _parser = parser {
    if (!plugin.enabled || plugin.catalog == null) {
      throw CatalogProviderUnavailableException(
        providerId: plugin.api,
        message: 'CMS provider is disabled or has no valid catalog config.',
      );
    }
  }

  static const _normalizer = CatalogNormalizer();
  static const _maxScanPages = 3;
  static const _maxDetailConcurrency = 3;

  final Plugin plugin;
  final CatalogGetJson _getJson;
  final CmsCatalogClock _now;
  final CmsPlaybackSourceParser _parser;

  PluginCatalogConfig get _catalog => plugin.catalog!;

  @override
  String get providerId => plugin.api;

  @override
  CatalogProviderCapabilities get capabilities => CatalogProviderCapabilities(
        modes: const {CatalogMode.playable},
        remoteDimensions: const {
          CatalogProviderDimensions.providerId,
          CatalogProviderDimensions.cursor,
        },
        localDimensions: const {
          CatalogProviderDimensions.text,
          CatalogProviderDimensions.genres,
          CatalogProviderDimensions.year,
          CatalogProviderDimensions.season,
          CatalogProviderDimensions.format,
          CatalogProviderDimensions.status,
          CatalogProviderDimensions.region,
          CatalogProviderDimensions.minimumScore,
          CatalogProviderDimensions.updatedWithin,
          CatalogProviderDimensions.adult,
          CatalogProviderDimensions.sort,
          CatalogProviderDimensions.playable,
        },
        remoteSorts: {
          if (_catalog.sorts.contains('updated')) CatalogSort.updatedAt,
          if (_catalog.sorts.contains('score')) CatalogSort.rating,
          if (_catalog.sorts.contains('popularity')) CatalogSort.popularity,
        },
      );

  @override
  Future<ProviderCatalogPage> query(CatalogQuery query) async {
    if (query.mode != CatalogMode.playable) {
      throw CatalogProviderUnavailableException(
        providerId: providerId,
        message: 'CMS catalog only supports playable browsing.',
      );
    }
    if (query.providerId != null && query.providerId != providerId) {
      throw CatalogProviderUnavailableException(
        providerId: query.providerId!,
        message: 'Requested CMS provider does not match this adapter.',
      );
    }
    final selection = _selectCategories(query);
    if (selection.categories.isEmpty) {
      return ProviderCatalogPage(
        remotelyEvaluated: selection.remoteDimensions,
        locallyEvaluated: _localDimensions(query, selection.remoteDimensions),
        complete: true,
      );
    }
    final cursor = ProviderCursor.decode(query.cursor, providerId: providerId);
    var categoryIndex = _nonNegativeInt(cursor['category']) ?? 0;
    var pageNumber = _positiveInt(cursor['page']) ?? 1;
    if (categoryIndex >= selection.categories.length) {
      throw CatalogProviderException(
        providerId: providerId,
        stage: 'cursor',
        message: 'CMS cursor points past configured categories.',
      );
    }

    final candidates = <String, _CmsCandidate>{};
    var scanned = 0;
    while (scanned < _maxScanPages &&
        categoryIndex < selection.categories.length) {
      final category = selection.categories[categoryIndex];
      final response = await _loadListPage(
        category: category,
        page: pageNumber,
        query: query,
      );
      scanned++;
      for (final raw in response.items) {
        final sourceItemId = raw['vod_id']?.toString().trim() ?? '';
        if (sourceItemId.isEmpty || (!query.includeAdult && _looksAdult(raw))) {
          continue;
        }
        candidates.putIfAbsent(
          sourceItemId,
          () => _CmsCandidate(
            raw: raw,
            category: category,
            includeAdult: query.includeAdult,
          ),
        );
      }
      if (pageNumber < response.pageCount) {
        pageNumber++;
      } else {
        categoryIndex++;
        pageNumber = 1;
      }
    }

    final complete = categoryIndex >= selection.categories.length;
    final hydrated = await _mapDetailsOrdered(candidates.values.toList());
    final items = hydrated
        .whereType<CatalogContent>()
        .where((content) => _matchesLocally(content, query))
        .toList(growable: false);
    items.sort((left, right) => _compare(left, right, query.sort));
    final remoteDimensions = <String>{
      CatalogProviderDimensions.providerId,
      CatalogProviderDimensions.cursor,
      ...selection.remoteDimensions,
      if (_remoteSortName(query.sort) case final sort?
          when _catalog.sorts.contains(sort))
        CatalogProviderDimensions.sort,
    };
    return ProviderCatalogPage(
      items: items,
      nextCursor: complete
          ? null
          : ProviderCursor.encode(
              providerId,
              {'category': categoryIndex, 'page': pageNumber},
            ),
      remotelyEvaluated: remoteDimensions,
      locallyEvaluated: _localDimensions(query, remoteDimensions),
      complete: complete,
      scannedUpstreamPages: scanned,
    );
  }

  _CategorySelection _selectCategories(CatalogQuery query) {
    var categories = List<PluginCatalogCategory>.from(_catalog.categories);
    final remote = <String>{};
    final regionCode = _regionFacet(query.region);
    if (regionCode != null) {
      final classified = categories
          .where((category) => category.facets.containsKey('region'))
          .toList(growable: false);
      final unclassified = categories
          .where((category) => !category.facets.containsKey('region'))
          .toList(growable: false);
      categories = [
        ...classified.where(
          (category) => category.facets['region'] == regionCode,
        ),
        ...unclassified,
      ];
      if (unclassified.isEmpty) remote.add(CatalogProviderDimensions.region);
    }
    return _CategorySelection(categories: categories, remoteDimensions: remote);
  }

  Future<_CmsListPage> _loadListPage({
    required PluginCatalogCategory category,
    required int page,
    required CatalogQuery query,
  }) async {
    final params = <String, String>{
      'ac': 'videolist',
      't': category.id,
      'pg': '$page',
    };
    final remoteSort = _remoteSortName(query.sort);
    if (remoteSort != null && _catalog.sorts.contains(remoteSort)) {
      params['sort'] = switch (remoteSort) {
        'updated' => 'time',
        'score' => 'score',
        'popularity' => 'hits',
        _ => remoteSort,
      };
    }
    try {
      final response = await _getJson(_apiUri(params), _headers);
      if (response is! Map) {
        throw const FormatException('CMS list response is not an object.');
      }
      final body = _stringMap(response);
      final values = body['list'] is List ? body['list'] as List : const [];
      return _CmsListPage(
        items: values.whereType<Map>().map(_stringMap).toList(growable: false),
        pageCount: _positiveInt(body['pagecount']) ?? page,
      );
    } catch (error) {
      if (error is CatalogProviderException) rethrow;
      throw CatalogProviderException(
        providerId: providerId,
        stage: 'list',
        message: 'CMS catalog list request failed.',
        cause: error,
      );
    }
  }

  Future<List<CatalogContent?>> _mapDetailsOrdered(
    List<_CmsCandidate> candidates,
  ) async {
    if (candidates.isEmpty) return const [];
    final results = List<CatalogContent?>.filled(candidates.length, null);
    var next = 0;
    Future<void> worker() async {
      while (true) {
        final index = next++;
        if (index >= candidates.length) return;
        results[index] = await _loadPlayableContent(candidates[index]);
      }
    }

    final workerCount = candidates.length < _maxDetailConcurrency
        ? candidates.length
        : _maxDetailConcurrency;
    await Future.wait(List.generate(workerCount, (_) => worker()));
    return results;
  }

  Future<CatalogContent?> _loadPlayableContent(_CmsCandidate candidate) async {
    final sourceItemId = candidate.raw['vod_id']!.toString();
    try {
      final response = await _getJson(
        _apiUri({'ac': 'detail', 'ids': sourceItemId}),
        _headers,
      );
      if (response is! Map) return null;
      final list = _stringMap(response)['list'];
      if (list is! List || list.isEmpty || list.first is! Map) return null;
      final detail = _stringMap(list.first as Map);
      final record = <String, Object?>{...candidate.raw, ...detail};
      if (!_catalogRecordMatchesPlugin(record, sourceItemId)) return null;
      if (!candidate.includeAdult && _looksAdult(record)) return null;
      final episodes = _parser.parse(
        playFrom: record['vod_play_from']?.toString() ?? '',
        playUrl: record['vod_play_url']?.toString() ?? '',
        headers: _headers,
      );
      final sourceIds = <String>{
        for (final episode in episodes)
          for (final source in episode.sources) source.id,
      };
      if (episodes.isEmpty || sourceIds.isEmpty) return null;
      return _toContent(
        record,
        category: candidate.category,
        sourceItemId: sourceItemId,
        routeCount: sourceIds.length,
      );
    } catch (error) {
      if (error is CatalogProviderException) rethrow;
      throw CatalogProviderException(
        providerId: providerId,
        stage: 'detail',
        message: 'CMS catalog detail request failed.',
        cause: error,
      );
    }
  }

  bool _catalogRecordMatchesPlugin(
    Map<String, Object?> record,
    String sourceItemId,
  ) {
    final detailId = record['vod_id']?.toString();
    return detailId == null || detailId.isEmpty || detailId == sourceItemId;
  }

  CatalogContent _toContent(
    Map<String, Object?> raw, {
    required PluginCatalogCategory category,
    required String sourceItemId,
    required int routeCount,
  }) {
    final title = raw['vod_name']?.toString().trim() ?? '';
    final genres = _normalizer.normalizeGenres([
      raw['vod_class']?.toString() ?? '',
      raw['type_name']?.toString() ?? '',
    ]);
    final score = double.tryParse(raw['vod_score']?.toString() ?? '');
    final updatedAt =
        DateTime.tryParse(raw['vod_time']?.toString() ?? '')?.toUtc();
    return CatalogContent(
      contentId: '',
      titles: CatalogTitles(
        primary: title,
        original: _nonEmpty(raw['vod_sub']?.toString()),
      ),
      normalizedTitle: _normalizer.normalizeTitle(title),
      year: _positiveInt(raw['vod_year']),
      format: _formatOf(raw),
      status: _normalizer.normalizeStatus(raw['vod_remarks']?.toString()),
      region: _regionOf(raw, category),
      genres: genres,
      ratings: {
        if (score != null)
          providerId: CatalogRating(score: score, source: providerId),
      },
      synopsis: _stripHtml(
        raw['vod_content']?.toString() ?? raw['vod_blurb']?.toString(),
      ),
      coverUrl: _coverUrl(raw['vod_pic']?.toString()),
      metadataUpdatedAt: updatedAt,
      externalRefs: [
        ExternalRef(namespace: 'cms:$providerId', id: sourceItemId),
      ],
      playableRefs: [
        PlayableRef(
          providerId: providerId,
          sourceItemId: sourceItemId,
          routeCount: routeCount,
        ),
      ],
    );
  }

  bool _matchesLocally(CatalogContent content, CatalogQuery query) {
    final search = _normalizer.normalizeTitle(query.text ?? '');
    if (search.isNotEmpty) {
      final titles = [
        content.titles.primary,
        if (content.titles.original != null) content.titles.original!,
        ...content.titles.aliases,
      ];
      if (!titles.any(
        (title) => _normalizer.normalizeTitle(title).contains(search),
      )) {
        return false;
      }
    }
    if (!content.genres.containsAll(query.genres)) return false;
    if (query.year != null && content.year != query.year) return false;
    if (query.season != null && content.season != query.season) return false;
    if (query.format != null && content.format != query.format) return false;
    if (query.status != null && content.status != query.status) return false;
    if (query.region != null && content.region != query.region) return false;
    final minimumScore = query.minimumScore;
    if (minimumScore != null &&
        !content.ratings.values.any(
          (rating) => rating.score != null && rating.score! >= minimumScore,
        )) {
      return false;
    }
    final updatedWithin = query.updatedWithin;
    if (updatedWithin != null) {
      final updatedAt = content.metadataUpdatedAt;
      if (updatedAt == null ||
          updatedAt.isBefore(_now().toUtc().subtract(updatedWithin))) {
        return false;
      }
    }
    return true;
  }

  Set<String> _localDimensions(
    CatalogQuery query,
    Set<String> remoteDimensions,
  ) =>
      {
        CatalogProviderDimensions.playable,
        CatalogProviderDimensions.adult,
        if (_nonEmpty(query.text) != null) CatalogProviderDimensions.text,
        if (query.genres.isNotEmpty) CatalogProviderDimensions.genres,
        if (query.year != null) CatalogProviderDimensions.year,
        if (query.season != null) CatalogProviderDimensions.season,
        if (query.format != null) CatalogProviderDimensions.format,
        if (query.status != null) CatalogProviderDimensions.status,
        if (query.region != null &&
            !remoteDimensions.contains(CatalogProviderDimensions.region))
          CatalogProviderDimensions.region,
        if (query.minimumScore != null) CatalogProviderDimensions.minimumScore,
        if (query.updatedWithin != null)
          CatalogProviderDimensions.updatedWithin,
        if (!remoteDimensions.contains(CatalogProviderDimensions.sort))
          CatalogProviderDimensions.sort,
      };

  int _compare(CatalogContent left, CatalogContent right, CatalogSort sort) {
    final result = switch (sort) {
      CatalogSort.title => left.titles.primary.compareTo(right.titles.primary),
      CatalogSort.rating => _compareNullableDouble(
          _bestScore(right),
          _bestScore(left),
        ),
      CatalogSort.updatedAt => _compareNullableDate(
          right.metadataUpdatedAt,
          left.metadataUpdatedAt,
        ),
      CatalogSort.releaseDate => (right.year ?? -1).compareTo(left.year ?? -1),
      _ => 0,
    };
    if (result != 0) return result;
    final leftId = left.playableRefs.firstOrNull?.sourceItemId ?? '';
    final rightId = right.playableRefs.firstOrNull?.sourceItemId ?? '';
    return leftId.compareTo(rightId);
  }

  Uri _apiUri(Map<String, String> queryParameters) {
    final base = plugin.baseUrl.trim().replaceFirst(RegExp(r'/+$'), '');
    return Uri.parse('$base/api.php/provide/vod/')
        .replace(queryParameters: queryParameters);
  }

  Map<String, String> get _headers => {
        'Accept': 'application/json',
        if (plugin.userAgent.trim().isNotEmpty)
          'User-Agent': plugin.userAgent.trim(),
        if (plugin.referer?.trim().isNotEmpty == true)
          'Referer': plugin.referer!.trim(),
      };

  String? _coverUrl(String? value) {
    final url = _nonEmpty(value);
    if (url == null) return null;
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    if (url.startsWith('//')) return 'https:$url';
    final base = plugin.baseUrl.trim().replaceFirst(RegExp(r'/+$'), '');
    return '$base/${url.replaceFirst(RegExp(r'^/+'), '')}';
  }

  static Future<Object?> _defaultGetJson(
    Uri uri,
    Map<String, String> headers,
  ) {
    return HttpClient().getJson(uri.toString(), headers: headers);
  }
}

class _CategorySelection {
  const _CategorySelection({
    required this.categories,
    required this.remoteDimensions,
  });

  final List<PluginCatalogCategory> categories;
  final Set<String> remoteDimensions;
}

class _CmsCandidate {
  const _CmsCandidate({
    required this.raw,
    required this.category,
    required this.includeAdult,
  });

  final Map<String, Object?> raw;
  final PluginCatalogCategory category;
  final bool includeAdult;
}

class _CmsListPage {
  const _CmsListPage({required this.items, required this.pageCount});

  final List<Map<String, Object?>> items;
  final int pageCount;
}

String? _regionFacet(CatalogRegion? region) => switch (region) {
      CatalogRegion.japan => 'jp',
      CatalogRegion.china => 'cn',
      CatalogRegion.korea => 'kr',
      CatalogRegion.western => 'western',
      CatalogRegion.other => 'other',
      _ => null,
    };

CatalogRegion _regionOf(
  Map<String, Object?> raw,
  PluginCatalogCategory category,
) {
  final normalized = const CatalogNormalizer().normalizeRegion(
    raw['vod_area']?.toString(),
  );
  if (normalized != CatalogRegion.unknown) return normalized;
  return switch (category.facets['region']) {
    'jp' => CatalogRegion.japan,
    'cn' => CatalogRegion.china,
    'kr' => CatalogRegion.korea,
    'western' => CatalogRegion.western,
    'other' => CatalogRegion.other,
    _ => CatalogRegion.unknown,
  };
}

CatalogFormat _formatOf(Map<String, Object?> raw) {
  const normalizer = CatalogNormalizer();
  for (final value in [raw['type_name'], raw['vod_class']]) {
    for (final token in (value?.toString() ?? '').split(RegExp(r'[,，/／|、]'))) {
      final format = normalizer.normalizeFormat(token);
      if (format != CatalogFormat.unknown) return format;
    }
  }
  return CatalogFormat.unknown;
}

String? _remoteSortName(CatalogSort sort) => switch (sort) {
      CatalogSort.updatedAt => 'updated',
      CatalogSort.rating => 'score',
      CatalogSort.popularity => 'popularity',
      _ => null,
    };

bool _looksAdult(Map<String, Object?> raw) {
  final haystack = [
    raw['vod_class'],
    raw['type_name'],
    raw['vod_remarks'],
    raw['vod_name'],
  ].map((value) => value?.toString() ?? '').join(' ');
  return RegExp(
    r'(?:18\+|r-?18|adult|hentai|里番|伦理片?|伦理剧|成人视频)',
    caseSensitive: false,
  ).hasMatch(haystack);
}

Map<String, Object?> _stringMap(Map value) =>
    value.map((key, item) => MapEntry(key.toString(), item));

int? _positiveInt(Object? value) {
  final parsed = value is int ? value : int.tryParse(value?.toString() ?? '');
  return parsed != null && parsed > 0 ? parsed : null;
}

int? _nonNegativeInt(Object? value) {
  final parsed = value is int ? value : int.tryParse(value?.toString() ?? '');
  return parsed != null && parsed >= 0 ? parsed : null;
}

String? _nonEmpty(String? value) {
  final normalized = value?.trim();
  return normalized == null || normalized.isEmpty ? null : normalized;
}

String? _stripHtml(String? value) {
  final normalized = _nonEmpty(value);
  if (normalized == null) return null;
  return normalized
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .replaceAll('&amp;', '&')
      .trim();
}

double? _bestScore(CatalogContent content) {
  double? score;
  for (final rating in content.ratings.values) {
    if (rating.score != null && (score == null || rating.score! > score)) {
      score = rating.score;
    }
  }
  return score;
}

int _compareNullableDouble(double? left, double? right) {
  if (left == null) return right == null ? 0 : 1;
  if (right == null) return -1;
  return left.compareTo(right);
}

int _compareNullableDate(DateTime? left, DateTime? right) {
  if (left == null) return right == null ? 0 : 1;
  if (right == null) return -1;
  return left.compareTo(right);
}
