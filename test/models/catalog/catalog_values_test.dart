import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:weila/models/catalog/catalog_enums.dart';
import 'package:weila/models/catalog/catalog_values.dart';

void main() {
  group('catalog enum codecs', () {
    test('catalog modes are discovery and playable with unknown fallback', () {
      expect(
        CatalogMode.values.map((value) => value.name),
        ['discovery', 'playable', 'unknown'],
      );
      expect(CatalogMode.fromName('cms'), CatalogMode.unknown);
      expect(CatalogMode.fromName('future-mode'), CatalogMode.unknown);
      expect(CatalogSeason.fromName('monsoon'), CatalogSeason.unknown);
      expect(CatalogFormat.fromName('hologram'), CatalogFormat.unknown);
      expect(CatalogStatus.fromName('paused-forever'), CatalogStatus.unknown);
      expect(CatalogRegion.fromName('moon'), CatalogRegion.unknown);
      expect(CatalogSort.fromName('random'), CatalogSort.unknown);
    });
  });

  group('CatalogTitles', () {
    test('round-trips optional fields in a schema-versioned map', () {
      const titles = CatalogTitles(
        primary: 'Frieren: Beyond Journey\'s End',
        original: 'Sousou no Frieren',
        english: 'Frieren: Beyond Journey\'s End',
        chinese: 'Frieren',
        aliases: ['Frieren', 'Sousou no Frieren'],
      );

      final encoded = titles.toMap();

      expect(encoded['schemaVersion'], 1);
      expect(CatalogTitles.fromMap(encoded), titles);
      expect(
        CatalogTitles.fromMap(const {
          'schemaVersion': 1,
          'primary': 'Only primary',
        }),
        const CatalogTitles(primary: 'Only primary'),
      );
    });
  });

  test('playable refs persist only structural source identity fields', () {
    const ref = PlayableRef(
      providerId: 'cms-main',
      sourceItemId: 'show-42',
      routeCount: 3,
    );

    expect(
      ref.toMap().keys,
      ['schemaVersion', 'providerId', 'sourceItemId', 'routeCount'],
    );
    expect(
      ref.storageKey,
      const PlayableRef(
        providerId: 'cms-main',
        sourceItemId: 'show-42',
        routeCount: 8,
      ).storageKey,
    );
    expect(
      PlayableRef.fromMap(const {
        'schemaVersion': 1,
        'providerId': 'legacy-cms',
        'itemId': 'legacy-show',
        'routeCount': 2,
      }),
      const PlayableRef(
        providerId: 'legacy-cms',
        sourceItemId: 'legacy-show',
        routeCount: 2,
      ),
    );
  });

  test('all catalog values round-trip reviewed fields and optional fields', () {
    const playableRef = PlayableRef(
      providerId: 'cms-main',
      sourceItemId: 'show-42',
      routeCount: 2,
    );
    final content = CatalogContent(
      contentId: 'content_opaque_01',
      titles: const CatalogTitles(
        primary: 'Frieren',
        original: 'Sousou no Frieren',
        aliases: ['Sousou no Frieren'],
      ),
      normalizedTitle: 'frieren',
      year: 2023,
      season: CatalogSeason.fall,
      format: CatalogFormat.tv,
      status: CatalogStatus.completed,
      region: CatalogRegion.japan,
      genres: const {'adventure', 'fantasy'},
      ratings: const {
        'mal': CatalogRating(score: 9.1, votes: 1200, source: 'mal'),
        'bangumi': CatalogRating(score: 8.8, votes: 3400, source: 'bangumi'),
      },
      synopsis: 'A journey after the journey.',
      coverUrl: 'https://images.example/frieren.jpg',
      metadataUpdatedAt: DateTime.utc(2026, 7, 16, 8),
      externalRefs: const [ExternalRef(namespace: 'mal', id: '52991')],
      playableRefs: const [playableRef],
    );
    const playableMatch = PlayableMatch(
      ref: playableRef,
      confidence: 0.98,
      confirmed: true,
      reason: 'external-ref',
    );
    const query = CatalogQuery(
      mode: CatalogMode.playable,
      text: 'Frieren',
      genres: {'fantasy', 'adventure'},
      year: 2023,
      season: CatalogSeason.fall,
      format: CatalogFormat.tv,
      status: CatalogStatus.completed,
      region: CatalogRegion.japan,
      minimumScore: 8.0,
      sort: CatalogSort.rating,
      providerId: 'cms-main',
      updatedWithin: Duration(days: 30),
      cursor: '12',
      limit: 36,
    );
    const coverage = CatalogQueryCoverage(
      modes: {CatalogMode.discovery, CatalogMode.playable},
      dimensions: {'genres', 'year'},
      complete: false,
    );
    final page = CatalogPage(
      items: [content],
      nextCursor: '48',
      coverage: coverage,
    );
    final cacheState = CatalogCacheState(
      page: page,
      storedAt: DateTime.utc(2026, 7, 16, 8),
      expiresAt: DateTime.utc(2026, 7, 17, 8),
    );

    final values = <(Map<String, Object?>, Object)>[
      (
        const CatalogRating(score: 9.1, votes: 1200, source: 'mal').toMap(),
        const CatalogRating(score: 9.1, votes: 1200, source: 'mal'),
      ),
      (
        const ExternalRef(namespace: 'mal', id: '52991').toMap(),
        const ExternalRef(namespace: 'mal', id: '52991'),
      ),
      (playableRef.toMap(), playableRef),
      (playableMatch.toMap(), playableMatch),
      (content.toMap(), content),
      (query.toMap(), query),
      (coverage.toMap(), coverage),
      (page.toMap(), page),
      (cacheState.toMap(), cacheState),
    ];
    for (final (map, _) in values) {
      expect(map['schemaVersion'], 1);
    }

    expect(CatalogRating.fromMap(values[0].$1), values[0].$2);
    expect(ExternalRef.fromMap(values[1].$1), values[1].$2);
    expect(PlayableRef.fromMap(values[2].$1), values[2].$2);
    expect(PlayableMatch.fromMap(values[3].$1), values[3].$2);
    expect(CatalogContent.fromMap(values[4].$1), values[4].$2);
    expect(CatalogQuery.fromMap(values[5].$1), values[5].$2);
    expect(CatalogQueryCoverage.fromMap(values[6].$1), values[6].$2);
    expect(CatalogPage.fromMap(values[7].$1), values[7].$2);
    expect(CatalogCacheState.fromMap(values[8].$1), values[8].$2);

    const sparse = CatalogContent(
      contentId: 'content_opaque_02',
      titles: CatalogTitles(primary: 'Sparse'),
    );
    expect(CatalogContent.fromMap(sparse.toMap()), sparse);
  });

  test('query serialization is stable with genres as its only set', () {
    const first = CatalogQuery(
      mode: CatalogMode.playable,
      genres: {'fantasy', 'action'},
      year: 2023,
      season: CatalogSeason.fall,
      format: CatalogFormat.tv,
      status: CatalogStatus.completed,
      region: CatalogRegion.japan,
      minimumScore: 8.0,
      providerId: 'cms-main',
      updatedWithin: Duration(days: 7),
      cursor: '24',
    );
    const reversed = CatalogQuery(
      mode: CatalogMode.playable,
      genres: {'action', 'fantasy'},
      year: 2023,
      season: CatalogSeason.fall,
      format: CatalogFormat.tv,
      status: CatalogStatus.completed,
      region: CatalogRegion.japan,
      minimumScore: 8.0,
      providerId: 'cms-main',
      updatedWithin: Duration(days: 7),
      cursor: '24',
    );
    const includingAdult = CatalogQuery(
      mode: CatalogMode.playable,
      genres: {'action', 'fantasy'},
      year: 2023,
      season: CatalogSeason.fall,
      format: CatalogFormat.tv,
      status: CatalogStatus.completed,
      region: CatalogRegion.japan,
      minimumScore: 8.0,
      providerId: 'cms-main',
      updatedWithin: Duration(days: 7),
      cursor: '24',
      includeAdult: true,
    );

    expect(jsonEncode(first.toMap()), jsonEncode(reversed.toMap()));
    expect(first.cacheKey, reversed.cacheKey);
    expect(first, reversed);
    expect(first.hashCode, reversed.hashCode);
    expect(first.toMap()['includeAdult'], isFalse);
    expect(includingAdult.toMap()['includeAdult'], isTrue);
    expect(CatalogQuery.fromMap(includingAdult.toMap()), includingAdult);
    expect(first.cacheKey, isNot(includingAdult.cacheKey));
    expect(first, isNot(includingAdult));
    expect(first.hashCode, isNot(includingAdult.hashCode));
  });

  test('content and coverage maps are stable regardless of map/set order', () {
    const firstContent = CatalogContent(
      contentId: 'opaque',
      titles: CatalogTitles(primary: 'Set order'),
      genres: {'fantasy', 'action'},
      ratings: {
        'mal': CatalogRating(score: 9),
        'bangumi': CatalogRating(score: 8),
      },
      externalRefs: [
        ExternalRef(namespace: 'mal', id: '2'),
        ExternalRef(namespace: 'bangumi', id: '1'),
      ],
      playableRefs: [
        PlayableRef(
          providerId: 'provider-b',
          sourceItemId: 'show-2',
          routeCount: 1,
        ),
        PlayableRef(
          providerId: 'provider-a',
          sourceItemId: 'show-1',
          routeCount: 3,
        ),
      ],
    );
    const reversedContent = CatalogContent(
      contentId: 'opaque',
      titles: CatalogTitles(primary: 'Set order'),
      genres: {'action', 'fantasy'},
      ratings: {
        'bangumi': CatalogRating(score: 8),
        'mal': CatalogRating(score: 9),
      },
      externalRefs: [
        ExternalRef(namespace: 'bangumi', id: '1'),
        ExternalRef(namespace: 'mal', id: '2'),
      ],
      playableRefs: [
        PlayableRef(
          providerId: 'provider-a',
          sourceItemId: 'show-1',
          routeCount: 3,
        ),
        PlayableRef(
          providerId: 'provider-b',
          sourceItemId: 'show-2',
          routeCount: 1,
        ),
      ],
    );
    const firstCoverage = CatalogQueryCoverage(
      modes: {CatalogMode.playable, CatalogMode.discovery},
      dimensions: {'year', 'genres'},
    );
    const reversedCoverage = CatalogQueryCoverage(
      modes: {CatalogMode.discovery, CatalogMode.playable},
      dimensions: {'genres', 'year'},
    );

    expect(firstContent, reversedContent);
    expect(firstContent.hashCode, reversedContent.hashCode);
    expect(
        jsonEncode(firstContent.toMap()), jsonEncode(reversedContent.toMap()));
    expect(firstCoverage, reversedCoverage);
    expect(firstCoverage.hashCode, reversedCoverage.hashCode);
    expect(
      jsonEncode(firstCoverage.toMap()),
      jsonEncode(reversedCoverage.toMap()),
    );
  });
}
