import '../../../models/catalog/catalog_enums.dart';
import '../../../models/catalog/catalog_values.dart';
import '../../http/http_client.dart';
import '../catalog_normalizer.dart';
import 'catalog_provider.dart';

class AniListCatalogProvider implements CatalogProvider {
  AniListCatalogProvider({CatalogPostJson? postJson})
      : _postJson = postJson ?? _defaultPostJson;

  static final Uri endpoint = Uri.parse('https://graphql.anilist.co');
  static const _normalizer = CatalogNormalizer();

  final CatalogPostJson _postJson;

  @override
  String get providerId => 'anilist';

  @override
  CatalogProviderCapabilities get capabilities =>
      const CatalogProviderCapabilities(
        modes: {CatalogMode.discovery},
        remoteDimensions: {
          CatalogProviderDimensions.text,
          CatalogProviderDimensions.year,
          CatalogProviderDimensions.season,
          CatalogProviderDimensions.format,
          CatalogProviderDimensions.status,
          CatalogProviderDimensions.region,
          CatalogProviderDimensions.minimumScore,
          CatalogProviderDimensions.sort,
          CatalogProviderDimensions.adult,
          CatalogProviderDimensions.cursor,
          CatalogProviderDimensions.limit,
        },
        localDimensions: {
          CatalogProviderDimensions.genres,
          CatalogProviderDimensions.minimumScore,
          CatalogProviderDimensions.updatedWithin,
        },
        remoteSorts: {
          CatalogSort.relevance,
          CatalogSort.popularity,
          CatalogSort.rating,
          CatalogSort.updatedAt,
          CatalogSort.releaseDate,
          CatalogSort.title,
        },
      );

  @override
  Future<ProviderCatalogPage> query(CatalogQuery query) async {
    if (query.mode != CatalogMode.discovery) {
      throw CatalogProviderUnavailableException(
        providerId: providerId,
        message: 'AniList only supports discovery browsing.',
      );
    }
    if (query.providerId != null && query.providerId != providerId) {
      throw CatalogProviderUnavailableException(
        providerId: query.providerId!,
        message: 'Requested provider is not AniList.',
      );
    }
    final cursor = ProviderCursor.decode(
      query.cursor,
      providerId: providerId,
    );
    final pageNumber = _positiveInt(cursor['page']) ?? 1;
    final variables = <String, Object?>{
      'page': pageNumber,
      'perPage': query.limit.clamp(1, 50),
      'search': _nonEmpty(query.text),
      'genres': query.genres.isEmpty
          ? null
          : (query.genres.map(_genreToAniList).toList()..sort()),
      'seasonYear': query.year,
      'season': _seasonToAniList(query.season),
      'formats': _formatsToAniList(query.format),
      'status': _statusToAniList(query.status),
      'country': _regionToAniList(query.region),
      'minimumScore': query.minimumScore == null
          ? null
          : (query.minimumScore! * 10).ceil() - 1,
      'sort':
          _sortToAniList(query.sort, hasSearch: _nonEmpty(query.text) != null),
      'isAdult': query.includeAdult ? null : false,
    };
    final response = await _request(variables);
    final data = _map(response['data']);
    final page = _map(data['Page']);
    final pageInfo = _map(page['pageInfo']);
    final rawItems = page['media'] is List ? page['media'] as List : const [];
    final parsed = rawItems
        .whereType<Map>()
        .map((raw) => _parseContent(_stringMap(raw)))
        .where((content) => _matchesLocally(content, query))
        .toList(growable: false);
    final hasNext = pageInfo['hasNextPage'] == true;
    final currentPage = _positiveInt(pageInfo['currentPage']) ?? pageNumber;
    final lastPage = _positiveInt(pageInfo['lastPage']);
    return ProviderCatalogPage(
      items: parsed,
      nextCursor: hasNext
          ? ProviderCursor.encode(providerId, {'page': currentPage + 1})
          : null,
      remotelyEvaluated: _remoteDimensions(query),
      locallyEvaluated: _localDimensions(query),
      complete: !hasNext,
      scannedUpstreamPages: 1,
      upstreamPageCount: lastPage,
    );
  }

  Future<Map<String, Object?>> _request(Map<String, Object?> variables) async {
    try {
      final response = await _postJson(
        endpoint,
        {'query': _browseQuery, 'variables': variables},
        const {
          'Accept': 'application/json',
          'Content-Type': 'application/json'
        },
      );
      if (response is! Map) {
        throw const FormatException('AniList response is not an object.');
      }
      final mapped = _stringMap(response);
      if (mapped['errors'] is List) {
        throw FormatException(
            'AniList returned GraphQL errors: ${mapped['errors']}');
      }
      return mapped;
    } catch (error) {
      if (error is CatalogProviderException) rethrow;
      throw CatalogProviderException(
        providerId: providerId,
        stage: 'request',
        message: 'AniList discovery request failed.',
        cause: error,
      );
    }
  }

  CatalogContent _parseContent(Map<String, Object?> raw) {
    final titles = _map(raw['title']);
    final primary = _firstNonEmpty([
      titles['romaji'],
      titles['english'],
      titles['native'],
    ]);
    final aliases =
        (raw['synonyms'] is List ? raw['synonyms'] as List : const [])
            .map((value) => value?.toString().trim() ?? '')
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList(growable: false);
    final rawGenres = (raw['genres'] is List ? raw['genres'] as List : const [])
        .map((value) => value?.toString() ?? '');
    final score = raw['averageScore'] is num
        ? (raw['averageScore'] as num).toDouble() / 10
        : null;
    final externalRefs = <ExternalRef>[
      if (raw['id'] != null)
        ExternalRef(namespace: 'anilist', id: raw['id'].toString()),
      if (raw['idMal'] != null)
        ExternalRef(namespace: 'mal', id: raw['idMal'].toString()),
    ];
    final updatedSeconds = _positiveInt(raw['updatedAt']);
    return CatalogContent(
      contentId: '',
      titles: CatalogTitles(
        primary: primary,
        original: _nonEmpty(titles['native']?.toString()),
        english: _nonEmpty(titles['english']?.toString()),
        aliases: aliases,
      ),
      normalizedTitle: _normalizer.normalizeTitle(primary),
      year: _positiveInt(raw['seasonYear']) ??
          _positiveInt(_map(raw['startDate'])['year']),
      season: _seasonFromAniList(raw['season']?.toString()),
      format: _formatFromAniList(raw['format']?.toString()),
      status: _statusFromAniList(raw['status']?.toString()),
      region: _regionFromAniList(raw['countryOfOrigin']?.toString()),
      genres: _normalizer.normalizeGenres(rawGenres),
      ratings: {
        if (score != null)
          'anilist': CatalogRating(score: score, source: 'anilist'),
      },
      synopsis: _stripHtml(raw['description']?.toString()),
      coverUrl: _firstNonEmptyOrNull([
        _map(raw['coverImage'])['extraLarge'],
        _map(raw['coverImage'])['large'],
      ]),
      metadataUpdatedAt: updatedSeconds == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(
              updatedSeconds * 1000,
              isUtc: true,
            ),
      externalRefs: externalRefs,
    );
  }

  bool _matchesLocally(CatalogContent content, CatalogQuery query) {
    if (!content.genres.containsAll(query.genres)) return false;
    final minimumScore = query.minimumScore;
    if (minimumScore != null &&
        !(content.ratings.values.any(
          (rating) => rating.score != null && rating.score! >= minimumScore,
        ))) {
      return false;
    }
    if (query.region == CatalogRegion.western ||
        query.region == CatalogRegion.other) {
      if (content.region != query.region) return false;
    }
    final updatedWithin = query.updatedWithin;
    if (updatedWithin != null) {
      final updatedAt = content.metadataUpdatedAt;
      if (updatedAt == null ||
          updatedAt.isBefore(DateTime.now().toUtc().subtract(updatedWithin))) {
        return false;
      }
    }
    return true;
  }

  Set<String> _remoteDimensions(CatalogQuery query) => {
        CatalogProviderDimensions.mode,
        CatalogProviderDimensions.adult,
        CatalogProviderDimensions.sort,
        CatalogProviderDimensions.cursor,
        CatalogProviderDimensions.limit,
        if (_nonEmpty(query.text) != null) CatalogProviderDimensions.text,
        if (query.year != null) CatalogProviderDimensions.year,
        if (query.season != null) CatalogProviderDimensions.season,
        if (query.format != null) CatalogProviderDimensions.format,
        if (query.status != null) CatalogProviderDimensions.status,
        if (_regionToAniList(query.region) != null)
          CatalogProviderDimensions.region,
        if (query.minimumScore != null) CatalogProviderDimensions.minimumScore,
      };

  Set<String> _localDimensions(CatalogQuery query) => {
        if (query.genres.isNotEmpty) CatalogProviderDimensions.genres,
        if (query.minimumScore != null) CatalogProviderDimensions.minimumScore,
        if (query.region == CatalogRegion.western ||
            query.region == CatalogRegion.other)
          CatalogProviderDimensions.region,
        if (query.updatedWithin != null)
          CatalogProviderDimensions.updatedWithin,
      };

  static Future<Object?> _defaultPostJson(
    Uri uri,
    Map<String, Object?> body,
    Map<String, String> headers,
  ) {
    return HttpClient().postJson(uri.toString(), data: body, headers: headers);
  }
}

const _browseQuery = r'''
query CatalogBrowse(
  $page: Int!,
  $perPage: Int!,
  $search: String,
  $genres: [String!],
  $seasonYear: Int,
  $season: MediaSeason,
  $formats: [MediaFormat!],
  $status: MediaStatus,
  $country: CountryCode,
  $minimumScore: Int,
  $sort: [MediaSort!],
  $isAdult: Boolean
) {
  Page(page: $page, perPage: $perPage) {
    pageInfo { currentPage hasNextPage lastPage }
    media(
      type: ANIME,
      search: $search,
      genre_in: $genres,
      seasonYear: $seasonYear,
      season: $season,
      format_in: $formats,
      status: $status,
      countryOfOrigin: $country,
      averageScore_greater: $minimumScore,
      sort: $sort,
      isAdult: $isAdult
    ) {
      id idMal
      title { romaji english native }
      synonyms genres seasonYear season format status countryOfOrigin
      averageScore coverImage { extraLarge large } description updatedAt
      startDate { year }
    }
  }
}
''';

String _genreToAniList(String value) =>
    const {
      'action': 'Action',
      'adventure': 'Adventure',
      'comedy': 'Comedy',
      'drama': 'Drama',
      'fantasy': 'Fantasy',
      'sciFi': 'Sci-Fi',
      'romance': 'Romance',
      'sliceOfLife': 'Slice of Life',
      'mystery': 'Mystery',
      'thriller': 'Thriller',
      'horror': 'Horror',
      'sports': 'Sports',
      'music': 'Music',
      'mecha': 'Mecha',
      'magicalGirl': 'Mahou Shoujo',
      'supernatural': 'Supernatural',
    }[value] ??
    value;

String? _seasonToAniList(CatalogSeason? value) => switch (value) {
      CatalogSeason.winter => 'WINTER',
      CatalogSeason.spring => 'SPRING',
      CatalogSeason.summer => 'SUMMER',
      CatalogSeason.fall => 'FALL',
      _ => null,
    };

CatalogSeason _seasonFromAniList(String? value) => switch (value) {
      'WINTER' => CatalogSeason.winter,
      'SPRING' => CatalogSeason.spring,
      'SUMMER' => CatalogSeason.summer,
      'FALL' => CatalogSeason.fall,
      _ => CatalogSeason.unknown,
    };

List<String>? _formatsToAniList(CatalogFormat? value) => switch (value) {
      CatalogFormat.tv => const ['TV', 'TV_SHORT'],
      CatalogFormat.movie => const ['MOVIE'],
      CatalogFormat.ova => const ['OVA'],
      CatalogFormat.ona => const ['ONA'],
      CatalogFormat.special => const ['SPECIAL'],
      CatalogFormat.music => const ['MUSIC'],
      _ => null,
    };

CatalogFormat _formatFromAniList(String? value) => switch (value) {
      'TV' || 'TV_SHORT' => CatalogFormat.tv,
      'MOVIE' => CatalogFormat.movie,
      'OVA' => CatalogFormat.ova,
      'ONA' => CatalogFormat.ona,
      'SPECIAL' => CatalogFormat.special,
      'MUSIC' => CatalogFormat.music,
      _ => CatalogFormat.unknown,
    };

String? _statusToAniList(CatalogStatus? value) => switch (value) {
      CatalogStatus.upcoming => 'NOT_YET_RELEASED',
      CatalogStatus.airing => 'RELEASING',
      CatalogStatus.completed => 'FINISHED',
      CatalogStatus.hiatus => 'HIATUS',
      CatalogStatus.cancelled => 'CANCELLED',
      _ => null,
    };

CatalogStatus _statusFromAniList(String? value) => switch (value) {
      'NOT_YET_RELEASED' => CatalogStatus.upcoming,
      'RELEASING' => CatalogStatus.airing,
      'FINISHED' => CatalogStatus.completed,
      'HIATUS' => CatalogStatus.hiatus,
      'CANCELLED' => CatalogStatus.cancelled,
      _ => CatalogStatus.unknown,
    };

String? _regionToAniList(CatalogRegion? value) => switch (value) {
      CatalogRegion.japan => 'JP',
      CatalogRegion.china => 'CN',
      CatalogRegion.korea => 'KR',
      _ => null,
    };

CatalogRegion _regionFromAniList(String? value) => switch (value) {
      'JP' => CatalogRegion.japan,
      'CN' => CatalogRegion.china,
      'KR' => CatalogRegion.korea,
      'US' || 'CA' || 'GB' || 'FR' || 'DE' => CatalogRegion.western,
      null || '' => CatalogRegion.unknown,
      _ => CatalogRegion.other,
    };

List<String> _sortToAniList(CatalogSort value, {required bool hasSearch}) =>
    switch (value) {
      CatalogSort.relevance when hasSearch => const ['SEARCH_MATCH'],
      CatalogSort.rating => const ['SCORE_DESC'],
      CatalogSort.updatedAt => const ['UPDATED_AT_DESC'],
      CatalogSort.releaseDate => const ['START_DATE_DESC'],
      CatalogSort.title => const ['TITLE_ROMAJI'],
      _ => const ['POPULARITY_DESC', 'SCORE_DESC'],
    };

Map<String, Object?> _map(Object? value) => value is Map
    ? value.map((key, item) => MapEntry(key.toString(), item))
    : const {};

Map<String, Object?> _stringMap(Map value) =>
    value.map((key, item) => MapEntry(key.toString(), item));

int? _positiveInt(Object? value) {
  final parsed = value is int ? value : int.tryParse(value?.toString() ?? '');
  return parsed != null && parsed > 0 ? parsed : null;
}

String _firstNonEmpty(Iterable<Object?> values) =>
    _firstNonEmptyOrNull(values) ?? '';

String? _firstNonEmptyOrNull(Iterable<Object?> values) {
  for (final value in values) {
    final normalized = _nonEmpty(value?.toString());
    if (normalized != null) return normalized;
  }
  return null;
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
      .replaceAll('&quot;', '"')
      .replaceAll('&#039;', "'")
      .trim();
}
