import 'dart:async';

import '../../../models/catalog/catalog_enums.dart';
import '../../../models/catalog/catalog_values.dart';
import '../../http/http_client.dart';
import '../catalog_normalizer.dart';
import 'catalog_provider.dart';

abstract interface class CatalogRequestLimiter {
  Future<void> acquire();
}

typedef JikanClock = DateTime Function();
typedef JikanDelay = Future<void> Function(Duration duration);

class JikanRequestLimiter implements CatalogRequestLimiter {
  JikanRequestLimiter({JikanClock? now, JikanDelay? delay})
      : _now = now ?? DateTime.now,
        _delay = delay ?? Future<void>.delayed;

  final JikanClock _now;
  final JikanDelay _delay;
  final List<DateTime> _admitted = [];
  Future<void> _tail = Future<void>.value();

  @override
  Future<void> acquire() {
    final result = _tail.then((_) => _waitForSlot());
    _tail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return result;
  }

  Future<void> _waitForSlot() async {
    while (true) {
      final now = _now().toUtc();
      _admitted.removeWhere(
        (instant) => !instant.isAfter(now.subtract(const Duration(minutes: 1))),
      );
      final inSecond = _admitted
          .where(
            (instant) =>
                instant.isAfter(now.subtract(const Duration(seconds: 1))),
          )
          .toList(growable: false);
      Duration wait = Duration.zero;
      if (inSecond.length >= 3) {
        wait = inSecond.first.add(const Duration(seconds: 1)).difference(now);
      }
      if (_admitted.length >= 60) {
        final minuteWait =
            _admitted.first.add(const Duration(minutes: 1)).difference(now);
        if (minuteWait > wait) wait = minuteWait;
      }
      if (wait <= Duration.zero) {
        _admitted.add(now);
        return;
      }
      await _delay(wait);
    }
  }
}

class JikanCatalogProvider implements CatalogProvider {
  JikanCatalogProvider({
    CatalogGetJson? getJson,
    CatalogRequestLimiter? limiter,
  })  : _getJson = getJson ?? _defaultGetJson,
        _limiter = limiter ?? _sharedLimiter;

  static final CatalogRequestLimiter _sharedLimiter = JikanRequestLimiter();
  static final Uri _endpoint = Uri.parse('https://api.jikan.moe/v4/anime');
  static const _normalizer = CatalogNormalizer();

  final CatalogGetJson _getJson;
  final CatalogRequestLimiter _limiter;
  final Map<String, Future<ProviderCatalogPage>> _inFlight = {};

  @override
  String get providerId => 'jikan';

  @override
  CatalogProviderCapabilities get capabilities =>
      const CatalogProviderCapabilities(
        modes: {CatalogMode.discovery},
        remoteDimensions: {
          CatalogProviderDimensions.text,
          CatalogProviderDimensions.year,
          CatalogProviderDimensions.format,
          CatalogProviderDimensions.status,
          CatalogProviderDimensions.minimumScore,
          CatalogProviderDimensions.sort,
          CatalogProviderDimensions.adult,
          CatalogProviderDimensions.cursor,
          CatalogProviderDimensions.limit,
        },
        localDimensions: {
          CatalogProviderDimensions.genres,
          CatalogProviderDimensions.season,
          CatalogProviderDimensions.status,
          CatalogProviderDimensions.region,
          CatalogProviderDimensions.minimumScore,
          CatalogProviderDimensions.updatedWithin,
        },
        remoteSorts: {
          CatalogSort.relevance,
          CatalogSort.popularity,
          CatalogSort.rating,
          CatalogSort.releaseDate,
          CatalogSort.title,
        },
      );

  @override
  Future<ProviderCatalogPage> query(CatalogQuery query) {
    if (query.mode != CatalogMode.discovery) {
      throw CatalogProviderUnavailableException(
        providerId: providerId,
        message: 'Jikan only supports discovery browsing.',
      );
    }
    if (query.providerId != null && query.providerId != providerId) {
      throw CatalogProviderUnavailableException(
        providerId: query.providerId!,
        message: 'Requested provider is not Jikan.',
      );
    }
    final uri = _buildUri(query);
    final key = uri.toString();
    final existing = _inFlight[key];
    if (existing != null) return existing;
    final request = _performQuery(query, uri);
    _inFlight[key] = request;
    request.then<void>(
      (_) {
        if (identical(_inFlight[key], request)) _inFlight.remove(key);
      },
      onError: (Object _, StackTrace __) {
        if (identical(_inFlight[key], request)) _inFlight.remove(key);
      },
    );
    return request;
  }

  Uri _buildUri(CatalogQuery query) {
    final cursor = ProviderCursor.decode(query.cursor, providerId: providerId);
    final page = _positiveInt(cursor['page']) ?? 1;
    final params = <String, String>{
      if (_nonEmpty(query.text) != null) 'q': _nonEmpty(query.text)!,
      'page': '$page',
      'limit': '${query.limit.clamp(1, 25)}',
      if (!query.includeAdult) 'sfw': 'true',
      if (_formatToJikan(query.format) case final value?) 'type': value,
      if (_statusToJikan(query.status) case final value?) 'status': value,
      if (query.minimumScore != null)
        'min_score': query.minimumScore.toString(),
      if (query.year != null) 'start_date': '${query.year}-01-01',
      if (query.year != null) 'end_date': '${query.year}-12-31',
    };
    final genreIds = query.genres
        .map((genre) => _genreIds[genre])
        .whereType<int>()
        .toList()
      ..sort();
    if (genreIds.isNotEmpty) params['genres'] = genreIds.join(',');
    final sort = _sortToJikan(query.sort);
    if (sort != null) {
      params['order_by'] = sort.$1;
      params['sort'] = sort.$2;
    }
    return _endpoint.replace(queryParameters: params);
  }

  Future<ProviderCatalogPage> _performQuery(
    CatalogQuery query,
    Uri uri,
  ) async {
    try {
      await _limiter.acquire();
      final response = await _getJson(
        uri,
        const {'Accept': 'application/json'},
      );
      if (response is! Map) {
        throw const FormatException('Jikan response is not an object.');
      }
      final body = _stringMap(response);
      final pagination = _map(body['pagination']);
      final rawItems = body['data'] is List ? body['data'] as List : const [];
      final items = rawItems
          .whereType<Map>()
          .map((raw) => _parseContent(_stringMap(raw)))
          .where((content) => _matchesLocally(content, query))
          .toList(growable: false);
      final hasNext = pagination['has_next_page'] == true;
      final currentPage = _positiveInt(pagination['current_page']) ?? 1;
      return ProviderCatalogPage(
        items: items,
        nextCursor: hasNext
            ? ProviderCursor.encode(providerId, {'page': currentPage + 1})
            : null,
        remotelyEvaluated: _remoteDimensions(query),
        locallyEvaluated: _localDimensions(query),
        complete: !hasNext,
        scannedUpstreamPages: 1,
        upstreamPageCount: _positiveInt(pagination['last_visible_page']),
      );
    } catch (error) {
      if (error is CatalogProviderException) rethrow;
      throw CatalogProviderException(
        providerId: providerId,
        stage: 'request',
        message: 'Jikan discovery request failed.',
        cause: error,
      );
    }
  }

  CatalogContent _parseContent(Map<String, Object?> raw) {
    final title = _firstNonEmpty([
      raw['title'],
      raw['title_english'],
      raw['title_japanese'],
    ]);
    final aliases = (raw['title_synonyms'] is List
            ? raw['title_synonyms'] as List
            : const [])
        .map((value) => value?.toString().trim() ?? '')
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList(growable: false);
    final genreNames = <String>[];
    for (final key in const [
      'genres',
      'explicit_genres',
      'themes',
      'demographics',
    ]) {
      final values = raw[key] is List ? raw[key] as List : const [];
      for (final value in values.whereType<Map>()) {
        final name = value['name']?.toString().trim() ?? '';
        if (name.isNotEmpty) genreNames.add(name);
      }
    }
    final score = raw['score'] is num ? (raw['score'] as num).toDouble() : null;
    final votes = _positiveInt(raw['scored_by']);
    final malId = _positiveInt(raw['mal_id']);
    return CatalogContent(
      contentId: '',
      titles: CatalogTitles(
        primary: title,
        original: _nonEmpty(raw['title_japanese']?.toString()),
        english: _nonEmpty(raw['title_english']?.toString()),
        aliases: aliases,
      ),
      normalizedTitle: _normalizer.normalizeTitle(title),
      year: _positiveInt(raw['year']) ??
          _positiveInt(_map(_map(_map(raw['aired'])['prop'])['from'])['year']),
      season: _seasonFromJikan(raw['season']?.toString()),
      format: _normalizer.normalizeFormat(raw['type']?.toString()),
      status: _normalizer.normalizeStatus(raw['status']?.toString()),
      region: CatalogRegion.unknown,
      genres: _normalizer.normalizeGenres(genreNames),
      ratings: {
        if (score != null)
          'mal': CatalogRating(score: score, votes: votes, source: 'mal'),
      },
      synopsis: _nonEmpty(raw['synopsis']?.toString()),
      coverUrl: _firstNonEmptyOrNull([
        _map(_map(raw['images'])['jpg'])['large_image_url'],
        _map(_map(raw['images'])['jpg'])['image_url'],
      ]),
      externalRefs: [
        if (malId != null) ExternalRef(namespace: 'mal', id: '$malId'),
      ],
    );
  }

  bool _matchesLocally(CatalogContent content, CatalogQuery query) {
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
    if (query.updatedWithin != null) return false;
    return true;
  }

  Set<String> _remoteDimensions(CatalogQuery query) => {
        CatalogProviderDimensions.mode,
        CatalogProviderDimensions.adult,
        CatalogProviderDimensions.cursor,
        CatalogProviderDimensions.limit,
        if (_nonEmpty(query.text) != null) CatalogProviderDimensions.text,
        if (query.year != null) CatalogProviderDimensions.year,
        if (_formatToJikan(query.format) != null)
          CatalogProviderDimensions.format,
        if (_statusToJikan(query.status) != null)
          CatalogProviderDimensions.status,
        if (query.minimumScore != null) CatalogProviderDimensions.minimumScore,
        if (_sortToJikan(query.sort) != null) CatalogProviderDimensions.sort,
      };

  Set<String> _localDimensions(CatalogQuery query) => {
        if (query.genres.isNotEmpty) CatalogProviderDimensions.genres,
        if (query.season != null) CatalogProviderDimensions.season,
        if (query.status != null && _statusToJikan(query.status) == null)
          CatalogProviderDimensions.status,
        if (query.region != null) CatalogProviderDimensions.region,
        if (query.minimumScore != null) CatalogProviderDimensions.minimumScore,
        if (query.updatedWithin != null)
          CatalogProviderDimensions.updatedWithin,
        if (query.sort == CatalogSort.updatedAt) CatalogProviderDimensions.sort,
      };

  static Future<Object?> _defaultGetJson(
    Uri uri,
    Map<String, String> headers,
  ) {
    return HttpClient().getJson(uri.toString(), headers: headers);
  }
}

String? _formatToJikan(CatalogFormat? value) => switch (value) {
      CatalogFormat.tv => 'tv',
      CatalogFormat.movie => 'movie',
      CatalogFormat.ova => 'ova',
      CatalogFormat.ona => 'ona',
      CatalogFormat.special => 'special',
      CatalogFormat.music => 'music',
      _ => null,
    };

String? _statusToJikan(CatalogStatus? value) => switch (value) {
      CatalogStatus.upcoming => 'upcoming',
      CatalogStatus.airing => 'airing',
      CatalogStatus.completed => 'complete',
      _ => null,
    };

(String, String)? _sortToJikan(CatalogSort value) => switch (value) {
      CatalogSort.popularity => ('popularity', 'asc'),
      CatalogSort.rating => ('score', 'desc'),
      CatalogSort.releaseDate => ('start_date', 'desc'),
      CatalogSort.title => ('title', 'asc'),
      _ => null,
    };

CatalogSeason _seasonFromJikan(String? value) => switch (value?.toLowerCase()) {
      'winter' => CatalogSeason.winter,
      'spring' => CatalogSeason.spring,
      'summer' => CatalogSeason.summer,
      'fall' => CatalogSeason.fall,
      _ => CatalogSeason.unknown,
    };

const _genreIds = <String, int>{
  'action': 1,
  'adventure': 2,
  'comedy': 4,
  'mystery': 7,
  'drama': 8,
  'fantasy': 10,
  'historical': 13,
  'horror': 14,
  'military': 38,
  'music': 19,
  'romance': 22,
  'school': 23,
  'sciFi': 24,
  'sports': 30,
  'supernatural': 37,
  'thriller': 41,
  'sliceOfLife': 36,
  'family': 15,
  'mecha': 18,
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
