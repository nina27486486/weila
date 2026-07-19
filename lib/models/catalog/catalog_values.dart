import 'dart:convert';

import 'catalog_enums.dart';

class CatalogTitles {
  const CatalogTitles({
    required this.primary,
    this.original,
    this.english,
    this.chinese,
    this.aliases = const [],
  });

  static const schemaVersion = 1;

  final String primary;
  final String? original;
  final String? english;
  final String? chinese;
  final List<String> aliases;

  Map<String, Object?> toMap() => {
        'schemaVersion': schemaVersion,
        'primary': primary,
        if (original != null) 'original': original,
        if (english != null) 'english': english,
        if (chinese != null) 'chinese': chinese,
        if (aliases.isNotEmpty) 'aliases': aliases,
      };

  factory CatalogTitles.fromMap(Map<String, Object?> map) => CatalogTitles(
        primary: map['primary']?.toString() ?? '',
        original: _optionalString(map['original']),
        english: _optionalString(map['english']),
        chinese: _optionalString(map['chinese']),
        aliases: _stringList(map['aliases']),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CatalogTitles &&
          primary == other.primary &&
          original == other.original &&
          english == other.english &&
          chinese == other.chinese &&
          _listEquals(aliases, other.aliases);

  @override
  int get hashCode => Object.hash(
        primary,
        original,
        english,
        chinese,
        Object.hashAll(aliases),
      );
}

class CatalogRating {
  const CatalogRating({this.score, this.votes, this.source});

  static const schemaVersion = 1;

  final double? score;
  final int? votes;
  final String? source;

  Map<String, Object?> toMap() => {
        'schemaVersion': schemaVersion,
        if (score != null) 'score': score,
        if (votes != null) 'votes': votes,
        if (source != null) 'source': source,
      };

  factory CatalogRating.fromMap(Map<String, Object?> map) => CatalogRating(
        score: _optionalDouble(map['score']),
        votes: _optionalInt(map['votes']),
        source: _optionalString(map['source']),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CatalogRating &&
          score == other.score &&
          votes == other.votes &&
          source == other.source;

  @override
  int get hashCode => Object.hash(score, votes, source);
}

class ExternalRef {
  const ExternalRef({required this.namespace, required this.id});

  static const schemaVersion = 1;

  final String namespace;
  final String id;

  String get storageKey => '${Uri.encodeComponent(namespace)}:'
      '${Uri.encodeComponent(id)}';

  Map<String, Object?> toMap() => {
        'schemaVersion': schemaVersion,
        'namespace': namespace,
        'id': id,
      };

  factory ExternalRef.fromMap(Map<String, Object?> map) => ExternalRef(
        namespace: map['namespace']?.toString() ?? '',
        id: map['id']?.toString() ?? '',
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExternalRef && namespace == other.namespace && id == other.id;

  @override
  int get hashCode => Object.hash(namespace, id);
}

class PlayableRef {
  const PlayableRef({
    required this.providerId,
    required this.sourceItemId,
    required this.routeCount,
  });

  static const schemaVersion = 1;

  final String providerId;
  final String sourceItemId;
  final int routeCount;

  String get storageKey =>
      [providerId, sourceItemId].map(Uri.encodeComponent).join(':');

  Map<String, Object?> toMap() => {
        'schemaVersion': schemaVersion,
        'providerId': providerId,
        'sourceItemId': sourceItemId,
        'routeCount': routeCount,
      };

  factory PlayableRef.fromMap(Map<String, Object?> map) => PlayableRef(
        providerId: map['providerId']?.toString() ?? '',
        sourceItemId:
            map['sourceItemId']?.toString() ?? map['itemId']?.toString() ?? '',
        routeCount: _optionalInt(map['routeCount']) ?? 0,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlayableRef &&
          providerId == other.providerId &&
          sourceItemId == other.sourceItemId &&
          routeCount == other.routeCount;

  @override
  int get hashCode => Object.hash(providerId, sourceItemId, routeCount);
}

class PlayableMatch {
  const PlayableMatch({
    required this.ref,
    required this.confidence,
    this.confirmed = false,
    this.reason,
  });

  static const schemaVersion = 1;

  final PlayableRef ref;
  final double confidence;
  final bool confirmed;
  final String? reason;

  Map<String, Object?> toMap() => {
        'schemaVersion': schemaVersion,
        'ref': ref.toMap(),
        'confidence': confidence,
        'confirmed': confirmed,
        if (reason != null) 'reason': reason,
      };

  factory PlayableMatch.fromMap(Map<String, Object?> map) => PlayableMatch(
        ref: PlayableRef.fromMap(_objectMap(map['ref'])),
        confidence: _optionalDouble(map['confidence']) ?? 0,
        confirmed: map['confirmed'] == true,
        reason: _optionalString(map['reason']),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlayableMatch &&
          ref == other.ref &&
          confidence == other.confidence &&
          confirmed == other.confirmed &&
          reason == other.reason;

  @override
  int get hashCode => Object.hash(ref, confidence, confirmed, reason);
}

class CatalogContent {
  const CatalogContent({
    required this.contentId,
    required this.titles,
    this.normalizedTitle = '',
    this.year,
    this.season = CatalogSeason.unknown,
    this.format = CatalogFormat.unknown,
    this.status = CatalogStatus.unknown,
    this.region = CatalogRegion.unknown,
    this.genres = const {},
    this.ratings = const {},
    this.synopsis,
    this.coverUrl,
    this.metadataUpdatedAt,
    this.externalRefs = const [],
    this.playableRefs = const [],
  });

  static const schemaVersion = 1;

  final String contentId;
  final CatalogTitles titles;
  final String normalizedTitle;
  final int? year;
  final CatalogSeason season;
  final CatalogFormat format;
  final CatalogStatus status;
  final CatalogRegion region;
  final Set<String> genres;
  final Map<String, CatalogRating> ratings;
  final String? synopsis;
  final String? coverUrl;
  final DateTime? metadataUpdatedAt;
  final List<ExternalRef> externalRefs;
  final List<PlayableRef> playableRefs;

  Map<String, Object?> toMap() => {
        'schemaVersion': schemaVersion,
        'contentId': contentId,
        'titles': titles.toMap(),
        if (normalizedTitle.isNotEmpty) 'normalizedTitle': normalizedTitle,
        if (year != null) 'year': year,
        if (season != CatalogSeason.unknown) 'season': season.name,
        if (format != CatalogFormat.unknown) 'format': format.name,
        if (status != CatalogStatus.unknown) 'status': status.name,
        if (region != CatalogRegion.unknown) 'region': region.name,
        if (genres.isNotEmpty) 'genres': _sortedStrings(genres),
        if (ratings.isNotEmpty)
          'ratings': {
            for (final source in _sortedStrings(ratings.keys))
              source: ratings[source]!.toMap(),
          },
        if (synopsis != null) 'synopsis': synopsis,
        if (coverUrl != null) 'coverUrl': coverUrl,
        if (metadataUpdatedAt != null)
          'metadataUpdatedAt': metadataUpdatedAt!.toUtc().toIso8601String(),
        if (externalRefs.isNotEmpty)
          'externalRefs': _sortedExternalRefs(externalRefs)
              .map((ref) => ref.toMap())
              .toList(),
        if (playableRefs.isNotEmpty)
          'playableRefs': _sortedPlayableRefs(playableRefs)
              .map((ref) => ref.toMap())
              .toList(),
      };

  factory CatalogContent.fromMap(Map<String, Object?> map) => CatalogContent(
        contentId: map['contentId']?.toString() ?? '',
        titles: CatalogTitles.fromMap(_objectMap(map['titles'])),
        normalizedTitle: map['normalizedTitle']?.toString() ?? '',
        year: _optionalInt(map['year']),
        season: CatalogSeason.fromName(map['season']),
        format: CatalogFormat.fromName(map['format']),
        status: CatalogStatus.fromName(map['status']),
        region: CatalogRegion.fromName(map['region']),
        genres: _stringSet(map['genres']),
        ratings: _ratingMap(map['ratings']),
        synopsis: _optionalString(map['synopsis']),
        coverUrl: _optionalString(map['coverUrl']),
        metadataUpdatedAt: _optionalDateTime(map['metadataUpdatedAt']),
        externalRefs: _mapList(map['externalRefs'])
            .map(ExternalRef.fromMap)
            .toList(growable: false),
        playableRefs: _mapList(map['playableRefs'])
            .map(PlayableRef.fromMap)
            .toList(growable: false),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CatalogContent &&
          contentId == other.contentId &&
          titles == other.titles &&
          normalizedTitle == other.normalizedTitle &&
          year == other.year &&
          season == other.season &&
          format == other.format &&
          status == other.status &&
          region == other.region &&
          _setEquals(genres, other.genres) &&
          _mapEquals(ratings, other.ratings) &&
          synopsis == other.synopsis &&
          coverUrl == other.coverUrl &&
          metadataUpdatedAt == other.metadataUpdatedAt &&
          _listEquals(
            _sortedExternalRefs(externalRefs),
            _sortedExternalRefs(other.externalRefs),
          ) &&
          _listEquals(
            _sortedPlayableRefs(playableRefs),
            _sortedPlayableRefs(other.playableRefs),
          );

  @override
  int get hashCode => Object.hash(
        contentId,
        titles,
        normalizedTitle,
        year,
        season,
        format,
        status,
        region,
        Object.hashAll(_sortedStrings(genres)),
        Object.hashAll(
          _sortedStrings(ratings.keys)
              .map((source) => Object.hash(source, ratings[source])),
        ),
        synopsis,
        coverUrl,
        metadataUpdatedAt,
        Object.hashAll(_sortedExternalRefs(externalRefs)),
        Object.hashAll(_sortedPlayableRefs(playableRefs)),
      );
}

class CatalogQuery {
  const CatalogQuery({
    this.mode = CatalogMode.discovery,
    this.text,
    this.genres = const {},
    this.year,
    this.season,
    this.format,
    this.status,
    this.region,
    this.minimumScore,
    this.includeAdult = false,
    this.sort = CatalogSort.relevance,
    this.providerId,
    this.updatedWithin,
    this.cursor,
    this.limit = 24,
  });

  static const schemaVersion = 1;

  final CatalogMode mode;
  final String? text;
  final Set<String> genres;
  final int? year;
  final CatalogSeason? season;
  final CatalogFormat? format;
  final CatalogStatus? status;
  final CatalogRegion? region;
  final double? minimumScore;
  final bool includeAdult;
  final CatalogSort sort;
  final String? providerId;
  final Duration? updatedWithin;
  final String? cursor;
  final int limit;

  String get cacheKey => jsonEncode(toMap());

  Map<String, Object?> toMap() => {
        'schemaVersion': schemaVersion,
        'mode': mode.name,
        if (text != null) 'text': text,
        if (genres.isNotEmpty) 'genres': _sortedStrings(genres),
        if (year != null) 'year': year,
        if (season != null) 'season': season!.name,
        if (format != null) 'format': format!.name,
        if (status != null) 'status': status!.name,
        if (region != null) 'region': region!.name,
        if (minimumScore != null) 'minimumScore': minimumScore,
        'includeAdult': includeAdult,
        'sort': sort.name,
        if (providerId != null) 'providerId': providerId,
        if (updatedWithin != null)
          'updatedWithinMs': updatedWithin!.inMilliseconds,
        if (cursor != null) 'cursor': cursor,
        'limit': limit,
      };

  factory CatalogQuery.fromMap(Map<String, Object?> map) => CatalogQuery(
        mode: CatalogMode.fromName(map['mode']),
        text: _optionalString(map['text']),
        genres: _stringSet(map['genres']),
        year: _optionalInt(map['year']),
        season: map.containsKey('season')
            ? CatalogSeason.fromName(map['season'])
            : null,
        format: map.containsKey('format')
            ? CatalogFormat.fromName(map['format'])
            : null,
        status: map.containsKey('status')
            ? CatalogStatus.fromName(map['status'])
            : null,
        region: map.containsKey('region')
            ? CatalogRegion.fromName(map['region'])
            : null,
        minimumScore: _optionalDouble(map['minimumScore']),
        includeAdult: map['includeAdult'] == true,
        sort: CatalogSort.fromName(map['sort']),
        providerId: _optionalString(map['providerId']),
        updatedWithin: _optionalDuration(map['updatedWithinMs']),
        cursor: _optionalString(map['cursor']),
        limit: _optionalInt(map['limit']) ?? 24,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CatalogQuery &&
          mode == other.mode &&
          text == other.text &&
          _setEquals(genres, other.genres) &&
          year == other.year &&
          season == other.season &&
          format == other.format &&
          status == other.status &&
          region == other.region &&
          minimumScore == other.minimumScore &&
          includeAdult == other.includeAdult &&
          sort == other.sort &&
          providerId == other.providerId &&
          updatedWithin == other.updatedWithin &&
          cursor == other.cursor &&
          limit == other.limit;

  @override
  int get hashCode => Object.hash(
        mode,
        text,
        Object.hashAll(_sortedStrings(genres)),
        year,
        season,
        format,
        status,
        region,
        minimumScore,
        includeAdult,
        sort,
        providerId,
        updatedWithin,
        cursor,
        limit,
      );
}

class CatalogQueryCoverage {
  const CatalogQueryCoverage({
    this.modes = const {},
    this.dimensions = const {},
    this.complete = false,
  });

  static const schemaVersion = 1;

  final Set<CatalogMode> modes;
  final Set<String> dimensions;
  final bool complete;

  Map<String, Object?> toMap() => {
        'schemaVersion': schemaVersion,
        if (modes.isNotEmpty) 'modes': _sortedEnumNames(modes),
        if (dimensions.isNotEmpty) 'dimensions': _sortedStrings(dimensions),
        'complete': complete,
      };

  factory CatalogQueryCoverage.fromMap(Map<String, Object?> map) =>
      CatalogQueryCoverage(
        modes: _enumSet(map['modes'], CatalogMode.fromName),
        dimensions: _stringSet(map['dimensions']),
        complete: map['complete'] == true,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CatalogQueryCoverage &&
          _setEquals(modes, other.modes) &&
          _setEquals(dimensions, other.dimensions) &&
          complete == other.complete;

  @override
  int get hashCode => Object.hash(
        Object.hashAll(_sortedEnumNames(modes)),
        Object.hashAll(_sortedStrings(dimensions)),
        complete,
      );
}

class CatalogPage {
  const CatalogPage({
    this.items = const [],
    this.nextCursor,
    this.coverage = const CatalogQueryCoverage(),
    this.warning,
  });

  static const schemaVersion = 1;

  final List<CatalogContent> items;
  final String? nextCursor;
  final CatalogQueryCoverage coverage;

  /// Transient status for consumers. It is deliberately not persisted so a
  /// successful cached read does not repeat an old network warning.
  final String? warning;

  Map<String, Object?> toMap() => {
        'schemaVersion': schemaVersion,
        'items': items.map((item) => item.toMap()).toList(),
        if (nextCursor != null) 'nextCursor': nextCursor,
        'coverage': coverage.toMap(),
      };

  factory CatalogPage.fromMap(Map<String, Object?> map) => CatalogPage(
        items: _mapList(map['items'])
            .map(CatalogContent.fromMap)
            .toList(growable: false),
        nextCursor: _optionalString(map['nextCursor']),
        coverage: CatalogQueryCoverage.fromMap(_objectMap(map['coverage'])),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CatalogPage &&
          _listEquals(items, other.items) &&
          nextCursor == other.nextCursor &&
          coverage == other.coverage &&
          warning == other.warning;

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(items), nextCursor, coverage, warning);
}

class CatalogCacheState {
  const CatalogCacheState({
    required this.page,
    required this.storedAt,
    required this.expiresAt,
  });

  static const schemaVersion = 1;

  final CatalogPage page;
  final DateTime storedAt;
  final DateTime expiresAt;

  Map<String, Object?> toMap() => {
        'schemaVersion': schemaVersion,
        'page': page.toMap(),
        'storedAt': storedAt.toUtc().toIso8601String(),
        'expiresAt': expiresAt.toUtc().toIso8601String(),
      };

  factory CatalogCacheState.fromMap(Map<String, Object?> map) =>
      CatalogCacheState(
        page: CatalogPage.fromMap(_objectMap(map['page'])),
        storedAt: _optionalDateTime(map['storedAt']) ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        expiresAt: _optionalDateTime(map['expiresAt']) ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CatalogCacheState &&
          page == other.page &&
          storedAt == other.storedAt &&
          expiresAt == other.expiresAt;

  @override
  int get hashCode => Object.hash(page, storedAt, expiresAt);
}

String? _optionalString(Object? value) {
  if (value == null) return null;
  return value.toString();
}

List<String> _stringList(Object? value) {
  if (value is! Iterable) return const [];
  return List<String>.unmodifiable(value.map((item) => item.toString()));
}

Set<String> _stringSet(Object? value) =>
    Set<String>.unmodifiable(_stringList(value));

Set<T> _enumSet<T>(Object? value, T Function(Object?) decode) {
  if (value is! Iterable) return <T>{};
  return Set<T>.unmodifiable(value.map(decode));
}

Map<String, Object?> _objectMap(Object? value) {
  if (value is! Map) return const {};
  return value.map((key, item) => MapEntry(key.toString(), item));
}

List<Map<String, Object?>> _mapList(Object? value) {
  if (value is! Iterable) return const [];
  return value.whereType<Map>().map(_objectMap).toList(growable: false);
}

Map<String, CatalogRating> _ratingMap(Object? value) {
  if (value is! Map) return const {};
  final ratings = <String, CatalogRating>{};
  for (final entry in value.entries) {
    if (entry.value is! Map) continue;
    ratings[entry.key.toString()] = CatalogRating.fromMap(
      _objectMap(entry.value),
    );
  }
  return Map<String, CatalogRating>.unmodifiable(ratings);
}

double? _optionalDouble(Object? value) =>
    value is num ? value.toDouble() : double.tryParse(value?.toString() ?? '');

int? _optionalInt(Object? value) =>
    value is num ? value.toInt() : int.tryParse(value?.toString() ?? '');

DateTime? _optionalDateTime(Object? value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString())?.toUtc();
}

Duration? _optionalDuration(Object? value) {
  final milliseconds = _optionalInt(value);
  return milliseconds == null ? null : Duration(milliseconds: milliseconds);
}

List<String> _sortedStrings(Iterable<String> values) => values.toList()..sort();

List<ExternalRef> _sortedExternalRefs(Iterable<ExternalRef> values) =>
    values.toList()
      ..sort((left, right) => left.storageKey.compareTo(right.storageKey));

List<PlayableRef> _sortedPlayableRefs(Iterable<PlayableRef> values) =>
    values.toList()
      ..sort((left, right) {
        final identityOrder = left.storageKey.compareTo(right.storageKey);
        return identityOrder != 0
            ? identityOrder
            : left.routeCount.compareTo(right.routeCount);
      });

List<String> _sortedEnumNames(Iterable<Enum> values) =>
    values.map((value) => value.name).toList()..sort();

bool _listEquals<T>(List<T> left, List<T> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index += 1) {
    if (left[index] != right[index]) return false;
  }
  return true;
}

bool _setEquals<T>(Set<T> left, Set<T> right) {
  if (left.length != right.length) return false;
  return left.containsAll(right);
}

bool _mapEquals<K, V>(Map<K, V> left, Map<K, V> right) {
  if (left.length != right.length) return false;
  for (final entry in left.entries) {
    if (!right.containsKey(entry.key) || right[entry.key] != entry.value) {
      return false;
    }
  }
  return true;
}
