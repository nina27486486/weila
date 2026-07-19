import 'package:flutter_test/flutter_test.dart';
import 'package:weila/models/catalog/catalog_enums.dart';
import 'package:weila/models/catalog/catalog_values.dart';
import 'package:weila/services/catalog/catalog_repository.dart';
import 'package:weila/services/catalog/hive_catalog_repository.dart';

void main() {
  test('stale cache remains visible when a refresh fails', () async {
    var now = DateTime.utc(2026, 7, 16, 8);
    var shouldFail = false;
    final repository = HiveCatalogRepository(
      entryStore: <String, Object?>{},
      referenceStore: <String, Object?>{},
      queryCacheStore: <String, Object?>{},
      now: () => now,
      loadPage: (_) async {
        if (shouldFail) throw StateError('offline');
        return const CatalogPage(
          items: [
            CatalogContent(
              contentId: 'remote-id',
              titles: CatalogTitles(primary: '缓存动画'),
            ),
          ],
        );
      },
    );

    final fresh = await repository.query(const CatalogQuery());
    shouldFail = true;
    now = now.add(const Duration(hours: 25));
    final stale = await repository.query(const CatalogQuery());

    expect(stale.items, fresh.items);
    expect(stale.warning, '目录更新失败，正在显示旧缓存结果。');
  });

  test('store persistence callback runs after catalog mutations', () async {
    var commits = 0;
    final repository = HiveCatalogRepository(
      entryStore: <String, Object?>{},
      referenceStore: <String, Object?>{},
      queryCacheStore: <String, Object?>{},
      persistStores: () async => commits += 1,
      createContentId: () => 'opaque-content',
      loadPage: (_) async => const CatalogPage(
        items: [
          CatalogContent(
            contentId: 'remote-id',
            titles: CatalogTitles(primary: '持久动画'),
          ),
        ],
      ),
    );

    await repository.query(const CatalogQuery());
    await repository.confirmPlayable(
      'opaque-content',
      const PlayableRef(
        providerId: 'cms-test',
        sourceItemId: '42',
        routeCount: 1,
      ),
    );

    expect(commits, 2);
  });

  test('injected clock drives fresh/stale cache and force refresh bypasses it',
      () async {
    final entries = <String, Object?>{};
    final references = <String, Object?>{};
    final queryCache = <String, Object?>{};
    var now = DateTime.utc(2026, 7, 16, 8);
    var loads = 0;
    final concrete = HiveCatalogRepository(
      entryStore: entries,
      referenceStore: references,
      queryCacheStore: queryCache,
      now: () => now,
      createContentId: () => 'opaque-content',
      loadPage: (query) async {
        loads += 1;
        return CatalogPage(
          items: [
            CatalogContent(
              contentId: 'provider-value-is-not-used-as-identity',
              titles: CatalogTitles(primary: 'load-$loads'),
              externalRefs: const [
                ExternalRef(namespace: 'mal', id: '52991'),
              ],
            ),
          ],
          nextCursor: 'cursor-$loads',
          coverage: const CatalogQueryCoverage(complete: true),
        );
      },
    );
    final CatalogRepository repository = concrete;
    const query = CatalogQuery(text: 'frieren');

    final initial = await repository.query(query);
    final fresh = await repository.query(query);
    final forced = await repository.query(query, forceRefresh: true);
    now = now.add(const Duration(hours: 25));
    final stale = await repository.query(query);

    expect(initial.items.single.titles.primary, 'load-1');
    expect(fresh, initial);
    expect(forced.items.single.titles.primary, 'load-2');
    expect(stale.items.single.titles.primary, 'load-3');
    expect(loads, 3);
    expect(queryCache, hasLength(1));
    expect(
      queryCache.values.single,
      isA<Map>().having((value) => value['schemaVersion'], 'version', 1),
    );
    expect(catalogEntriesStoreName, 'catalog_entries_v1');
    expect(catalogReferencesStoreName, 'catalog_refs_v1');
    expect(catalogQueryCacheStoreName, 'catalog_query_cache_v1');
  });

  test('playable mode uses the 30 minute CMS list cache TTL', () async {
    var now = DateTime.utc(2026, 7, 16, 8);
    var loads = 0;
    final repository = HiveCatalogRepository(
      entryStore: <String, Object?>{},
      referenceStore: <String, Object?>{},
      queryCacheStore: <String, Object?>{},
      now: () => now,
      loadPage: (query) async {
        loads += 1;
        return const CatalogPage();
      },
    );
    const query = CatalogQuery(mode: CatalogMode.playable);

    await repository.query(query);
    now = now.add(const Duration(minutes: 29));
    await repository.query(query);
    expect(loads, 1);

    now = now.add(const Duration(minutes: 2));
    await repository.query(query);
    expect(loads, 2);
  });

  test('initializing twice is idempotent and preserves stored data', () async {
    const stored = CatalogContent(
      contentId: 'opaque-existing',
      titles: CatalogTitles(primary: 'Existing entry'),
    );
    final entries = <String, Object?>{stored.contentId: stored.toMap()};
    final references = <String, Object?>{
      'external:existing': const {
        'schemaVersion': 1,
        'kind': 'external',
        'contentId': 'opaque-existing',
      },
    };
    final queryCache = <String, Object?>{};
    final entriesBefore = Map<String, Object?>.from(entries);
    final referencesBefore = Map<String, Object?>.from(references);

    final first = HiveCatalogRepository(
      entryStore: entries,
      referenceStore: references,
      queryCacheStore: queryCache,
    );
    await first.initialize();
    await first.initialize();

    final second = HiveCatalogRepository(
      entryStore: entries,
      referenceStore: references,
      queryCacheStore: queryCache,
    );
    await second.initialize();

    expect(await first.getById(stored.contentId), stored);
    expect(await second.getById(stored.contentId), stored);
    expect(entries, entriesBefore);
    expect(references, referencesBefore);
  });

  test('playable lookup and confirmation touch references, never media URLs',
      () async {
    const contentId = 'opaque-existing';
    const candidateRef = PlayableRef(
      providerId: 'cms-main',
      sourceItemId: 'show-42',
      routeCount: 2,
    );
    const confirmedRef = PlayableRef(
      providerId: 'cms-backup',
      sourceItemId: 'show-9000',
      routeCount: 1,
    );
    final entry = <String, Object?>{
      ...const CatalogContent(
        contentId: contentId,
        titles: CatalogTitles(primary: 'Legacy-safe entry'),
      ).toMap(),
      'legacyMediaUrl': 'https://video.example/legacy.m3u8',
    };
    final entries = <String, Object?>{contentId: entry};
    final entryBefore = Map<String, Object?>.from(entry);
    final references = <String, Object?>{
      'playable:seed': {
        'schemaVersion': 1,
        'kind': 'playable',
        'contentId': contentId,
        'match': const PlayableMatch(
          ref: candidateRef,
          confidence: 0.72,
          reason: 'provider-candidate',
        ).toMap(),
        'expiresAt': DateTime.utc(2026, 7, 16, 14).toIso8601String(),
      },
    };
    final entriesBefore = Map<String, Object?>.from(entries);
    final repository = HiveCatalogRepository(
      entryStore: entries,
      referenceStore: references,
      queryCacheStore: <String, Object?>{},
      now: () => DateTime.utc(2026, 7, 16, 8),
    );

    final candidates = await repository.findPlayable(contentId);
    final refsBeforeConfirm = Map<String, Object?>.from(references);
    await repository.confirmPlayable(contentId, confirmedRef);
    final afterConfirm = await repository.findPlayable(contentId);

    expect(candidates, const [
      PlayableMatch(
        ref: candidateRef,
        confidence: 0.72,
        reason: 'provider-candidate',
      ),
    ]);
    expect(references, isNot(refsBeforeConfirm));
    expect(
      afterConfirm,
      contains(const PlayableMatch(
        ref: confirmedRef,
        confidence: 1,
        confirmed: true,
        reason: 'confirmed',
      )),
    );
    expect(entries, entriesBefore);
    expect(entries[contentId], entryBefore);
    expect(
      (entries[contentId] as Map)['legacyMediaUrl'],
      'https://video.example/legacy.m3u8',
    );
    expect(
      references.values.whereType<Map>().every(
            (value) =>
                !value.containsKey('mediaUrl') && !value.containsKey('url'),
          ),
      isTrue,
    );
  });

  test('local repository query requires every selected genre', () async {
    const both = CatalogContent(
      contentId: 'opaque-both',
      titles: CatalogTitles(primary: 'Both'),
      genres: {'action', 'fantasy'},
    );
    const actionOnly = CatalogContent(
      contentId: 'opaque-action',
      titles: CatalogTitles(primary: 'Action only'),
      genres: {'action'},
    );
    const fantasyOnly = CatalogContent(
      contentId: 'opaque-fantasy',
      titles: CatalogTitles(primary: 'Fantasy only'),
      genres: {'fantasy'},
    );
    final repository = HiveCatalogRepository(
      entryStore: <String, Object?>{
        both.contentId: both.toMap(),
        actionOnly.contentId: actionOnly.toMap(),
        fantasyOnly.contentId: fantasyOnly.toMap(),
      },
      referenceStore: <String, Object?>{},
      queryCacheStore: <String, Object?>{},
    );

    final page = await repository.query(
      const CatalogQuery(genres: {'action', 'fantasy'}),
    );

    expect(page.items.map((item) => item.contentId), ['opaque-both']);
  });

  test('local repository applies every scalar metadata filter', () async {
    final now = DateTime.utc(2026, 7, 16, 8);
    const playableRef = PlayableRef(
      providerId: 'cms-main',
      sourceItemId: 'show-42',
      routeCount: 2,
    );
    final content = CatalogContent(
      contentId: 'opaque-frieren',
      titles: const CatalogTitles(
        primary: 'Frieren: Beyond Journey\'s End',
        aliases: ['Sousou no Frieren'],
      ),
      year: 2023,
      season: CatalogSeason.fall,
      format: CatalogFormat.tv,
      status: CatalogStatus.completed,
      region: CatalogRegion.japan,
      genres: const {'adventure', 'fantasy'},
      ratings: const {
        'mal': CatalogRating(score: 9.1, votes: 1200),
      },
      metadataUpdatedAt: now.subtract(const Duration(days: 2)),
      playableRefs: const [playableRef],
    );
    final repository = HiveCatalogRepository(
      entryStore: <String, Object?>{content.contentId: content.toMap()},
      referenceStore: <String, Object?>{},
      queryCacheStore: <String, Object?>{},
      now: () => now,
    );
    await repository.confirmPlayable(content.contentId, playableRef);
    Future<List<String>> ids(CatalogQuery query) async =>
        (await repository.query(query))
            .items
            .map((item) => item.contentId)
            .toList();

    expect(await ids(const CatalogQuery(text: 'sousou')), ['opaque-frieren']);
    expect(await ids(const CatalogQuery(text: 'not present')), isEmpty);
    expect(await ids(const CatalogQuery(year: 2023)), ['opaque-frieren']);
    expect(await ids(const CatalogQuery(year: 2024)), isEmpty);
    expect(await ids(const CatalogQuery(season: CatalogSeason.fall)), [
      'opaque-frieren',
    ]);
    expect(
        await ids(const CatalogQuery(season: CatalogSeason.spring)), isEmpty);
    expect(await ids(const CatalogQuery(format: CatalogFormat.tv)), [
      'opaque-frieren',
    ]);
    expect(await ids(const CatalogQuery(format: CatalogFormat.movie)), isEmpty);
    expect(await ids(const CatalogQuery(status: CatalogStatus.completed)), [
      'opaque-frieren',
    ]);
    expect(
        await ids(const CatalogQuery(status: CatalogStatus.airing)), isEmpty);
    expect(await ids(const CatalogQuery(region: CatalogRegion.japan)), [
      'opaque-frieren',
    ]);
    expect(await ids(const CatalogQuery(region: CatalogRegion.china)), isEmpty);
    expect(await ids(const CatalogQuery(minimumScore: 9)), ['opaque-frieren']);
    expect(await ids(const CatalogQuery(minimumScore: 9.2)), isEmpty);
    expect(await ids(const CatalogQuery(providerId: 'cms-main')), [
      'opaque-frieren',
    ]);
    expect(await ids(const CatalogQuery(providerId: 'cms-other')), isEmpty);
    expect(
      await ids(const CatalogQuery(updatedWithin: Duration(days: 3))),
      ['opaque-frieren'],
    );
    expect(
      await ids(const CatalogQuery(updatedWithin: Duration(days: 1))),
      isEmpty,
    );
    expect(
      await ids(const CatalogQuery(genres: {'adventure', 'fantasy'})),
      ['opaque-frieren'],
    );
    expect(
      await ids(const CatalogQuery(genres: {'adventure', 'romance'})),
      isEmpty,
    );
  });

  test('playable mode excludes content without a playable reference', () async {
    const playableRef = PlayableRef(
      providerId: 'cms-main',
      sourceItemId: 'show-42',
      routeCount: 2,
    );
    const playable = CatalogContent(
      contentId: 'a-playable',
      titles: CatalogTitles(primary: 'Playable'),
      playableRefs: [playableRef],
    );
    const metadataOnly = CatalogContent(
      contentId: 'b-metadata-only',
      titles: CatalogTitles(primary: 'Metadata only'),
    );
    final repository = HiveCatalogRepository(
      entryStore: <String, Object?>{
        playable.contentId: playable.toMap(),
        metadataOnly.contentId: metadataOnly.toMap(),
      },
      referenceStore: <String, Object?>{},
      queryCacheStore: <String, Object?>{},
    );
    await repository.confirmPlayable(playable.contentId, playableRef);

    final discovery = await repository.query(const CatalogQuery());
    final playablePage = await repository.query(
      const CatalogQuery(mode: CatalogMode.playable),
    );
    final providerPage = await repository.query(
      const CatalogQuery(
        mode: CatalogMode.playable,
        providerId: 'cms-main',
      ),
    );

    expect(discovery.items.map((item) => item.contentId), [
      'a-playable',
      'b-metadata-only',
    ]);
    expect(playablePage.items.map((item) => item.contentId), ['a-playable']);
    expect(providerPage.items.map((item) => item.contentId), ['a-playable']);
  });

  test('local repository applies each catalog sort deterministically',
      () async {
    final beta = CatalogContent(
      contentId: 'id-a',
      titles: const CatalogTitles(primary: 'Beta'),
      year: 2022,
      ratings: const {
        'source': CatalogRating(score: 9, votes: 10),
      },
      metadataUpdatedAt: DateTime.utc(2026, 7, 15),
    );
    final alpha = CatalogContent(
      contentId: 'id-b',
      titles: const CatalogTitles(primary: 'Alpha'),
      year: 2024,
      ratings: const {
        'source': CatalogRating(score: 8, votes: 100),
      },
      metadataUpdatedAt: DateTime.utc(2026, 7, 14),
    );
    final gamma = CatalogContent(
      contentId: 'id-c',
      titles: const CatalogTitles(primary: 'Gamma'),
      year: 2023,
      metadataUpdatedAt: DateTime.utc(2026, 7, 16),
    );
    final repository = HiveCatalogRepository(
      entryStore: <String, Object?>{
        beta.contentId: beta.toMap(),
        alpha.contentId: alpha.toMap(),
        gamma.contentId: gamma.toMap(),
      },
      referenceStore: <String, Object?>{},
      queryCacheStore: <String, Object?>{},
    );
    Future<List<String>> ids(CatalogSort sort) async =>
        (await repository.query(CatalogQuery(sort: sort)))
            .items
            .map((item) => item.contentId)
            .toList();

    expect(await ids(CatalogSort.title), ['id-b', 'id-a', 'id-c']);
    expect(await ids(CatalogSort.rating), ['id-a', 'id-b', 'id-c']);
    expect(await ids(CatalogSort.popularity), ['id-b', 'id-a', 'id-c']);
    expect(await ids(CatalogSort.updatedAt), ['id-c', 'id-a', 'id-b']);
    expect(await ids(CatalogSort.releaseDate), ['id-b', 'id-c', 'id-a']);
  });

  test('cursor and limit drive pages and truthful query coverage', () async {
    final now = DateTime.utc(2026, 7, 16, 8);
    const playableRef = PlayableRef(
      providerId: 'cms-main',
      sourceItemId: 'show',
      routeCount: 1,
    );
    CatalogContent item(String contentId, String title) => CatalogContent(
          contentId: contentId,
          titles: CatalogTitles(primary: 'Series $title'),
          year: 2024,
          season: CatalogSeason.summer,
          format: CatalogFormat.tv,
          status: CatalogStatus.airing,
          region: CatalogRegion.japan,
          genres: const {'action'},
          ratings: const {
            'mal': CatalogRating(score: 8.5, votes: 100),
          },
          metadataUpdatedAt: now.subtract(const Duration(days: 1)),
          playableRefs: const [playableRef],
        );
    final alpha = item('id-alpha', 'Alpha');
    final beta = item('id-beta', 'Beta');
    final repository = HiveCatalogRepository(
      entryStore: <String, Object?>{
        alpha.contentId: alpha.toMap(),
        beta.contentId: beta.toMap(),
      },
      referenceStore: <String, Object?>{},
      queryCacheStore: <String, Object?>{},
      now: () => now,
    );
    await repository.confirmPlayable(alpha.contentId, playableRef);
    await repository.confirmPlayable(beta.contentId, playableRef);
    CatalogQuery query({String? cursor}) => CatalogQuery(
          mode: CatalogMode.playable,
          text: 'series',
          genres: const {'action'},
          year: 2024,
          season: CatalogSeason.summer,
          format: CatalogFormat.tv,
          status: CatalogStatus.airing,
          region: CatalogRegion.japan,
          minimumScore: 8,
          sort: CatalogSort.title,
          providerId: 'cms-main',
          updatedWithin: const Duration(days: 7),
          cursor: cursor,
          limit: 1,
        );

    final first = await repository.query(query());
    final second = await repository.query(query(cursor: '1'));

    expect(first.items.map((item) => item.contentId), ['id-alpha']);
    expect(first.nextCursor, '1');
    expect(first.coverage.modes, {CatalogMode.playable});
    expect(first.coverage.dimensions, {
      'playable',
      'text',
      'genres',
      'year',
      'season',
      'format',
      'status',
      'region',
      'minimumScore',
      'sort',
      'providerId',
      'updatedWithin',
      'limit',
    });
    expect(first.coverage.complete, isFalse);

    expect(second.items.map((item) => item.contentId), ['id-beta']);
    expect(second.nextCursor, isNull);
    expect(second.coverage.dimensions, {
      'playable',
      'text',
      'genres',
      'year',
      'season',
      'format',
      'status',
      'region',
      'minimumScore',
      'sort',
      'providerId',
      'updatedWithin',
      'cursor',
      'limit',
    });
    expect(second.coverage.complete, isTrue);
  });

  test('confirmed playable binding expires after six hours', () async {
    var now = DateTime.utc(2026, 7, 16, 8);
    const ref = PlayableRef(
      providerId: 'cms-main',
      sourceItemId: 'show-42',
      routeCount: 2,
    );
    final repository = HiveCatalogRepository(
      entryStore: <String, Object?>{},
      referenceStore: <String, Object?>{},
      queryCacheStore: <String, Object?>{},
      now: () => now,
    );

    await repository.confirmPlayable('opaque-content', ref);
    expect(await repository.findPlayable('opaque-content'), const [
      PlayableMatch(
        ref: ref,
        confidence: 1,
        confirmed: true,
        reason: 'confirmed',
      ),
    ]);

    now = now.add(const Duration(hours: 5, minutes: 59));
    expect(await repository.findPlayable('opaque-content'), hasLength(1));

    now = now.add(const Duration(minutes: 2));
    expect(await repository.findPlayable('opaque-content'), isEmpty);
  });

  test('loader playable refs become repository playable matches', () async {
    final now = DateTime.utc(2026, 7, 16, 8);
    const ref = PlayableRef(
      providerId: 'cms-main',
      sourceItemId: 'show-42',
      routeCount: 3,
    );
    final references = <String, Object?>{};
    final repository = HiveCatalogRepository(
      entryStore: <String, Object?>{},
      referenceStore: references,
      queryCacheStore: <String, Object?>{},
      now: () => now,
      createContentId: () => 'opaque-loaded',
      loadPage: (_) async => const CatalogPage(
        items: [
          CatalogContent(
            contentId: 'provider-owned-id',
            titles: CatalogTitles(primary: 'Loaded playable'),
            externalRefs: [ExternalRef(namespace: 'mal', id: '52991')],
            playableRefs: [ref],
          ),
        ],
      ),
    );

    final page = await repository.query(const CatalogQuery());
    final matches = await repository.findPlayable('opaque-loaded');
    final stored = await repository.getById('opaque-loaded');

    expect(page.items.single.playableRefs, const [ref]);
    expect(matches.map((match) => match.ref), const [ref]);
    expect(stored?.playableRefs, const [ref]);
    expect(
      references.values.whereType<Map>().every(
            (value) =>
                !value.containsKey('mediaUrl') && !value.containsKey('url'),
          ),
      isTrue,
    );
  });

  test('local playable truth comes only from unexpired reference records',
      () async {
    var now = DateTime.utc(2026, 7, 16, 8);
    const staleEntryRef = PlayableRef(
      providerId: 'cms-stale',
      sourceItemId: 'stale-show',
      routeCount: 9,
    );
    const confirmedRef = PlayableRef(
      providerId: 'cms-live',
      sourceItemId: 'live-show',
      routeCount: 2,
    );
    const content = CatalogContent(
      contentId: 'opaque-playable-truth',
      titles: CatalogTitles(primary: 'Playable truth'),
      playableRefs: [staleEntryRef],
    );
    final repository = HiveCatalogRepository(
      entryStore: <String, Object?>{content.contentId: content.toMap()},
      referenceStore: <String, Object?>{},
      queryCacheStore: <String, Object?>{},
      now: () => now,
    );

    expect(
      (await repository.query(
        const CatalogQuery(mode: CatalogMode.playable),
      ))
          .items,
      isEmpty,
    );

    await repository.confirmPlayable(content.contentId, confirmedRef);
    expect(
      (await repository.query(
        const CatalogQuery(
          mode: CatalogMode.playable,
          providerId: 'cms-live',
        ),
      ))
          .items
          .map((item) => item.contentId),
      [content.contentId],
    );
    expect(
      (await repository.query(
        const CatalogQuery(providerId: 'cms-live'),
      ))
          .items
          .map((item) => item.contentId),
      [content.contentId],
    );
    expect(
      (await repository.getById(content.contentId))?.playableRefs,
      const [confirmedRef],
    );

    now = now.add(const Duration(hours: 6, minutes: 1));
    expect(
      (await repository.query(
        const CatalogQuery(mode: CatalogMode.playable),
      ))
          .items,
      isEmpty,
    );
    expect(
      (await repository.query(
        const CatalogQuery(providerId: 'cms-live'),
      ))
          .items,
      isEmpty,
    );
    expect(
      (await repository.getById(content.contentId))?.playableRefs,
      isEmpty,
    );
  });
}
