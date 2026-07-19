import 'package:flutter_test/flutter_test.dart';
import 'package:weila/models/catalog/catalog_enums.dart';
import 'package:weila/models/catalog/catalog_values.dart';
import 'package:weila/services/catalog/providers/anilist_catalog_provider.dart';

void main() {
  test('AniList translates discovery facets and parses normalized content',
      () async {
    Uri? capturedUri;
    Map<String, Object?>? capturedBody;
    final provider = AniListCatalogProvider(
      postJson: (uri, body, headers) async {
        capturedUri = uri;
        capturedBody = body;
        return {
          'data': {
            'Page': {
              'pageInfo': {
                'currentPage': 1,
                'hasNextPage': true,
                'lastPage': 3,
              },
              'media': [
                {
                  'id': 154587,
                  'idMal': 52991,
                  'title': {
                    'romaji': 'Sousou no Frieren',
                    'english': 'Frieren: Beyond Journey’s End',
                    'native': '葬送のフリーレン',
                  },
                  'synonyms': ['Frieren'],
                  'genres': ['Adventure', 'Fantasy'],
                  'seasonYear': 2023,
                  'season': 'FALL',
                  'format': 'TV',
                  'status': 'FINISHED',
                  'countryOfOrigin': 'JP',
                  'averageScore': 91,
                  'coverImage': {
                    'extraLarge': 'https://img.example/frieren.jpg',
                  },
                  'description': '<b>A journey</b> after the journey.',
                  'updatedAt': 1700000000,
                },
              ],
            },
          },
        };
      },
    );

    final page = await provider.query(
      const CatalogQuery(
        text: 'Frieren',
        genres: {'adventure', 'fantasy'},
        year: 2023,
        season: CatalogSeason.fall,
        format: CatalogFormat.tv,
        status: CatalogStatus.completed,
        region: CatalogRegion.japan,
        minimumScore: 8,
        sort: CatalogSort.rating,
        limit: 24,
      ),
    );

    expect(capturedUri, Uri.parse('https://graphql.anilist.co'));
    final variables = capturedBody!['variables'] as Map<String, Object?>;
    expect(variables['page'], 1);
    expect(variables['perPage'], 24);
    expect(variables['search'], 'Frieren');
    expect(variables['genres'], ['Adventure', 'Fantasy']);
    expect(variables['seasonYear'], 2023);
    expect(variables['season'], 'FALL');
    expect(variables['formats'], containsAll(['TV', 'TV_SHORT']));
    expect(variables['status'], 'FINISHED');
    expect(variables['country'], 'JP');
    expect(variables['minimumScore'], 79);
    expect(variables['sort'], ['SCORE_DESC']);
    expect(variables['isAdult'], isFalse);
    expect((capturedBody!['query'] as String), contains('type: ANIME'));

    expect(page.nextCursor, isNotNull);
    expect(page.complete, isFalse);
    expect(page.scannedUpstreamPages, 1);
    expect(page.remotelyEvaluated, contains('year'));
    expect(page.locallyEvaluated, contains('genres'));
    expect(page.items, hasLength(1));
    final item = page.items.single;
    expect(item.contentId, isEmpty);
    expect(item.titles.primary, 'Sousou no Frieren');
    expect(item.titles.english, 'Frieren: Beyond Journey’s End');
    expect(item.titles.original, '葬送のフリーレン');
    expect(item.titles.aliases, ['Frieren']);
    expect(item.genres, {'adventure', 'fantasy'});
    expect(item.ratings['anilist']?.score, 9.1);
    expect(item.externalRefs,
        contains(const ExternalRef(namespace: 'anilist', id: '154587')));
    expect(item.externalRefs,
        contains(const ExternalRef(namespace: 'mal', id: '52991')));
    expect(item.region, CatalogRegion.japan);
    expect(item.synopsis, 'A journey after the journey.');
    expect(item.metadataUpdatedAt,
        DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000, isUtc: true));
  });

  test(
      'AniList cursor is provider-scoped and adult=true removes the adult filter',
      () async {
    final pages = <Object?>[];
    final adultValues = <Object?>[];
    final provider = AniListCatalogProvider(
      postJson: (uri, body, headers) async {
        final variables = body['variables'] as Map<String, Object?>;
        pages.add(variables['page']);
        adultValues.add(variables['isAdult']);
        return {
          'data': {
            'Page': {
              'pageInfo': {
                'currentPage': variables['page'],
                'hasNextPage': pages.length == 1,
                'lastPage': 2,
              },
              'media': const [],
            },
          },
        };
      },
    );

    final first = await provider.query(const CatalogQuery(includeAdult: true));
    await provider.query(
      CatalogQuery(includeAdult: true, cursor: first.nextCursor),
    );

    expect(pages, [1, 2]);
    expect(adultValues, [null, null]);
  });

  test(
      'AniList applies genre AND locally even when upstream returns a partial match',
      () async {
    final provider = AniListCatalogProvider(
      postJson: (uri, body, headers) async => {
        'data': {
          'Page': {
            'pageInfo': {
              'currentPage': 1,
              'hasNextPage': false,
              'lastPage': 1,
            },
            'media': [
              {
                'id': 1,
                'title': {'romaji': 'Fantasy only'},
                'genres': ['Fantasy'],
              },
            ],
          },
        },
      },
    );

    final page = await provider.query(
      const CatalogQuery(genres: {'fantasy', 'action'}),
    );

    expect(page.items, isEmpty);
    expect(page.complete, isTrue);
    expect(page.locallyEvaluated, contains('genres'));
  });
}
