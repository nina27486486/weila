import 'package:flutter_test/flutter_test.dart';
import 'package:weila/models/catalog/catalog_enums.dart';
import 'package:weila/models/catalog/catalog_values.dart';
import 'package:weila/services/catalog/catalog_identity_resolver.dart';

void main() {
  test('same external reference keeps its persisted opaque ID across upserts',
      () {
    final entries = <String, Object?>{};
    final references = <String, Object?>{};
    var createdIds = 0;
    String createId() => 'opaque-${++createdIds}';
    var resolver = CatalogIdentityResolver(
      entryStore: entries,
      referenceStore: references,
      createContentId: createId,
    );

    final first = resolver.upsert(
      _candidate(
        contentId: 'https://media.example/source.m3u8',
        refs: const [ExternalRef(namespace: 'mal', id: '52991')],
      ),
    );
    final second = resolver.upsert(
      _candidate(
        contentId: 'source-provided-id',
        refs: const [ExternalRef(namespace: 'mal', id: '52991')],
      ),
    );

    resolver = CatalogIdentityResolver(
      entryStore: entries,
      referenceStore: references,
      createContentId: createId,
    );
    final afterRestart = resolver.upsert(
      _candidate(
        contentId: '',
        refs: const [ExternalRef(namespace: 'mal', id: '52991')],
      ),
    );

    expect(first.contentId, 'opaque-1');
    expect(second.contentId, first.contentId);
    expect(afterRestart.contentId, first.contentId);
    expect(createdIds, 1);
    expect(Uri.tryParse(first.contentId)?.hasScheme, isFalse);
    expect(entries[first.contentId], isA<Map>());
    expect(references, isNotEmpty);
  });

  test('auto-link requires normalized title, year, and format together', () {
    final entries = <String, Object?>{};
    final references = <String, Object?>{};
    var createdIds = 0;
    final resolver = CatalogIdentityResolver(
      entryStore: entries,
      referenceStore: references,
      createContentId: () => 'opaque-${++createdIds}',
    );

    final original = resolver.upsert(
      _candidate(
        contentId: '',
        refs: const [ExternalRef(namespace: 'mal', id: '52991')],
        title: 'Frieren: Beyond Journey\'s End',
      ),
    );
    final exactIdentity = resolver.upsert(
      _candidate(
        contentId: '',
        refs: const [ExternalRef(namespace: 'bangumi', id: '400602')],
        title: ' frieren beyond journey’s end ',
      ),
    );
    final titleOnly = resolver.upsert(
      _candidate(
        contentId: '',
        refs: const [],
        title: 'Frieren: Beyond Journey\'s End',
        year: null,
        format: CatalogFormat.unknown,
      ),
    );
    final wrongYear = resolver.upsert(
      _candidate(
        contentId: '',
        refs: const [],
        title: 'Frieren: Beyond Journey\'s End',
        year: 2024,
      ),
    );
    final wrongFormat = resolver.upsert(
      _candidate(
        contentId: '',
        refs: const [],
        title: 'Frieren: Beyond Journey\'s End',
        format: CatalogFormat.movie,
      ),
    );
    final wrongTitle = resolver.upsert(
      _candidate(
        contentId: '',
        refs: const [],
        title: 'Frieren Season 2',
      ),
    );

    expect(exactIdentity.contentId, original.contentId);
    expect(
      {
        titleOnly.contentId,
        wrongYear.contentId,
        wrongFormat.contentId,
        wrongTitle.contentId,
      },
      hasLength(4),
    );
    expect(titleOnly.contentId, isNot(original.contentId));
    expect(wrongYear.contentId, isNot(original.contentId));
    expect(wrongFormat.contentId, isNot(original.contentId));
    expect(wrongTitle.contentId, isNot(original.contentId));
  });

  test('sparse upsert preserves previously stored rich metadata', () {
    final entries = <String, Object?>{};
    final references = <String, Object?>{};
    final resolver = CatalogIdentityResolver(
      entryStore: entries,
      referenceStore: references,
      createContentId: () => 'opaque-rich',
    );
    const externalRef = ExternalRef(namespace: 'mal', id: '52991');
    const playableRef = PlayableRef(
      providerId: 'cms-main',
      sourceItemId: 'show-42',
      routeCount: 2,
    );
    final updatedAt = DateTime.utc(2026, 7, 15, 8);
    final rich = resolver.upsert(
      CatalogContent(
        contentId: '',
        titles: const CatalogTitles(primary: 'Frieren'),
        year: 2023,
        format: CatalogFormat.tv,
        genres: const {'adventure', 'fantasy'},
        ratings: const {
          'mal': CatalogRating(score: 9.1, votes: 1200, source: 'mal'),
        },
        synopsis: 'Rich synopsis',
        coverUrl: 'https://images.example/rich.jpg',
        metadataUpdatedAt: updatedAt,
        externalRefs: const [externalRef],
        playableRefs: const [playableRef],
      ),
    );

    final sparse = resolver.upsert(
      const CatalogContent(
        contentId: '',
        titles: CatalogTitles(primary: 'Frieren'),
        externalRefs: [externalRef],
      ),
    );

    expect(sparse.contentId, rich.contentId);
    expect(sparse.year, 2023);
    expect(sparse.format, CatalogFormat.tv);
    expect(sparse.genres, {'adventure', 'fantasy'});
    expect(sparse.ratings, rich.ratings);
    expect(sparse.synopsis, 'Rich synopsis');
    expect(sparse.coverUrl, 'https://images.example/rich.jpg');
    expect(sparse.metadataUpdatedAt, updatedAt);
    expect(sparse.externalRefs, const [externalRef]);
    expect(sparse.playableRefs, const [playableRef]);
  });

  test('newer upsert enriches metadata without replacing prior sources', () {
    final resolver = CatalogIdentityResolver(
      entryStore: <String, Object?>{},
      referenceStore: <String, Object?>{},
      createContentId: () => 'opaque-progressive',
    );
    const malRef = ExternalRef(namespace: 'mal', id: '52991');
    const bangumiRef = ExternalRef(namespace: 'bangumi', id: '400602');
    const primaryPlayable = PlayableRef(
      providerId: 'cms-main',
      sourceItemId: 'show-42',
      routeCount: 2,
    );
    const backupPlayable = PlayableRef(
      providerId: 'cms-backup',
      sourceItemId: 'show-9000',
      routeCount: 1,
    );
    resolver.upsert(
      CatalogContent(
        contentId: '',
        titles: const CatalogTitles(primary: 'Frieren'),
        year: 2023,
        format: CatalogFormat.tv,
        genres: const {'adventure'},
        ratings: const {
          'mal': CatalogRating(score: 9.1, votes: 1200),
        },
        synopsis: 'Old synopsis',
        coverUrl: 'https://images.example/old.jpg',
        metadataUpdatedAt: DateTime.utc(2026, 7, 14, 8),
        externalRefs: const [malRef],
        playableRefs: const [primaryPlayable],
      ),
    );

    final enriched = resolver.upsert(
      CatalogContent(
        contentId: '',
        titles: const CatalogTitles(primary: 'Frieren'),
        genres: const {'fantasy'},
        ratings: const {
          'bangumi': CatalogRating(score: 8.8, votes: 3400),
        },
        synopsis: 'New synopsis',
        coverUrl: 'https://images.example/new.jpg',
        metadataUpdatedAt: DateTime.utc(2026, 7, 16, 8),
        externalRefs: const [malRef, bangumiRef],
        playableRefs: const [backupPlayable],
      ),
    );

    expect(enriched.year, 2023);
    expect(enriched.format, CatalogFormat.tv);
    expect(enriched.genres, {'adventure', 'fantasy'});
    expect(enriched.ratings, {
      'mal': const CatalogRating(score: 9.1, votes: 1200),
      'bangumi': const CatalogRating(score: 8.8, votes: 3400),
    });
    expect(enriched.synopsis, 'New synopsis');
    expect(enriched.coverUrl, 'https://images.example/new.jpg');
    expect(enriched.metadataUpdatedAt, DateTime.utc(2026, 7, 16, 8));
    expect(enriched.externalRefs, const [bangumiRef, malRef]);
    expect(enriched.playableRefs, const [backupPlayable, primaryPlayable]);
  });

  test('progressive merge applies timestamp priority fieldwise', () {
    final resolver = CatalogIdentityResolver(
      entryStore: <String, Object?>{},
      referenceStore: <String, Object?>{},
      createContentId: () => 'opaque-timestamped',
    );
    const externalRef = ExternalRef(namespace: 'mal', id: '52991');
    final current = resolver.upsert(
      CatalogContent(
        contentId: '',
        titles: const CatalogTitles(
          primary: 'Current Primary',
          original: 'Current Original',
          english: 'Current English',
          chinese: '当前中文',
          aliases: ['Alpha', 'Shared'],
        ),
        normalizedTitle: 'current primary',
        year: 2023,
        season: CatalogSeason.fall,
        format: CatalogFormat.tv,
        status: CatalogStatus.completed,
        region: CatalogRegion.japan,
        synopsis: 'Current synopsis',
        coverUrl: 'https://images.example/current.jpg',
        metadataUpdatedAt: DateTime.utc(2026, 7, 16, 8),
        externalRefs: const [externalRef],
      ),
    );

    final afterOlder = resolver.upsert(
      CatalogContent(
        contentId: '',
        titles: const CatalogTitles(primary: 'Older Primary'),
        normalizedTitle: 'older primary',
        year: 2024,
        season: CatalogSeason.winter,
        format: CatalogFormat.movie,
        status: CatalogStatus.airing,
        region: CatalogRegion.china,
        synopsis: 'Older synopsis',
        coverUrl: 'https://images.example/older.jpg',
        metadataUpdatedAt: DateTime.utc(2026, 7, 15, 8),
        externalRefs: const [externalRef],
      ),
    );

    expect(afterOlder.year, current.year);
    expect(afterOlder.season, current.season);
    expect(afterOlder.format, current.format);
    expect(afterOlder.status, current.status);
    expect(afterOlder.region, current.region);
    expect(afterOlder.titles, current.titles);
    expect(afterOlder.normalizedTitle, current.normalizedTitle);
    expect(afterOlder.synopsis, current.synopsis);
    expect(afterOlder.coverUrl, current.coverUrl);

    final afterNewerSparseTitle = resolver.upsert(
      CatalogContent(
        contentId: '',
        titles: const CatalogTitles(
          primary: 'Newest Primary',
          aliases: ['Shared', 'Beta'],
        ),
        normalizedTitle: 'newest primary',
        metadataUpdatedAt: DateTime.utc(2026, 7, 17, 8),
        externalRefs: const [externalRef],
      ),
    );

    expect(
      afterNewerSparseTitle.titles,
      const CatalogTitles(
        primary: 'Newest Primary',
        original: 'Current Original',
        english: 'Current English',
        chinese: '当前中文',
        aliases: ['Alpha', 'Shared', 'Beta'],
      ),
    );
    expect(afterNewerSparseTitle.year, 2023);
    expect(afterNewerSparseTitle.season, CatalogSeason.fall);
    expect(afterNewerSparseTitle.format, CatalogFormat.tv);
    expect(afterNewerSparseTitle.status, CatalogStatus.completed);
    expect(afterNewerSparseTitle.region, CatalogRegion.japan);
  });

  test('constant ID factory falls back deterministically without looping', () {
    var factoryCalls = 0;
    String constantFactory() {
      factoryCalls += 1;
      if (factoryCalls > 2) {
        throw StateError('ID factory called repeatedly for one upsert');
      }
      return 'opaque-constant';
    }

    final resolver = CatalogIdentityResolver(
      entryStore: <String, Object?>{},
      referenceStore: <String, Object?>{},
      createContentId: constantFactory,
    );

    final first = resolver.upsert(
      _candidate(
        contentId: '',
        refs: const [],
        title: 'First unrelated title',
      ),
    );
    final second = resolver.upsert(
      _candidate(
        contentId: '',
        refs: const [],
        title: 'Second unrelated title',
      ),
    );

    expect(first.contentId, 'opaque-constant');
    expect(second.contentId, 'opaque-constant_1');
    expect(factoryCalls, 2);
  });
}

CatalogContent _candidate({
  required String contentId,
  required List<ExternalRef> refs,
  String title = 'Frieren',
  int? year = 2023,
  CatalogFormat format = CatalogFormat.tv,
}) =>
    CatalogContent(
      contentId: contentId,
      titles: CatalogTitles(primary: title),
      year: year,
      format: format,
      externalRefs: refs,
    );
