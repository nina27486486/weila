import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:weila/models/catalog/catalog_enums.dart';
import 'package:weila/models/catalog/catalog_values.dart';
import 'package:weila/services/catalog/providers/jikan_catalog_provider.dart';

void main() {
  test('Jikan translates supported filters and parses all metadata genres',
      () async {
    Uri? capturedUri;
    final provider = JikanCatalogProvider(
      getJson: (uri, headers) async {
        capturedUri = uri;
        return {
          'pagination': {
            'last_visible_page': 4,
            'has_next_page': true,
            'current_page': 1,
          },
          'data': [
            {
              'mal_id': 52991,
              'title': 'Sousou no Frieren',
              'title_english': 'Frieren: Beyond Journey’s End',
              'title_japanese': '葬送のフリーレン',
              'title_synonyms': ['Frieren'],
              'images': {
                'jpg': {'large_image_url': 'https://img.example/frieren.jpg'},
              },
              'synopsis': 'A journey after the journey.',
              'score': 9.1,
              'scored_by': 100000,
              'year': 2023,
              'season': 'fall',
              'type': 'TV',
              'status': 'Finished Airing',
              'genres': [
                {'name': 'Adventure'},
              ],
              'themes': [
                {'name': 'Fantasy'},
              ],
              'explicit_genres': const [],
              'demographics': [
                {'name': 'Shounen'},
              ],
            },
          ],
        };
      },
      limiter: _CountingLimiter(),
    );

    final page = await provider.query(
      const CatalogQuery(
        genres: {'adventure', 'fantasy'},
        year: 2023,
        format: CatalogFormat.tv,
        status: CatalogStatus.completed,
        minimumScore: 8,
        sort: CatalogSort.rating,
      ),
    );

    expect(capturedUri!.path, '/v4/anime');
    expect(capturedUri!.queryParameters['page'], '1');
    expect(capturedUri!.queryParameters['limit'], '24');
    expect(capturedUri!.queryParameters['type'], 'tv');
    expect(capturedUri!.queryParameters['status'], 'complete');
    expect(capturedUri!.queryParameters['min_score'], '8.0');
    expect(capturedUri!.queryParameters['start_date'], '2023-01-01');
    expect(capturedUri!.queryParameters['end_date'], '2023-12-31');
    expect(capturedUri!.queryParameters['genres'], '2,10');
    expect(capturedUri!.queryParameters['order_by'], 'score');
    expect(capturedUri!.queryParameters['sort'], 'desc');
    expect(capturedUri!.queryParameters['sfw'], 'true');

    expect(page.items, hasLength(1));
    final item = page.items.single;
    expect(item.genres, containsAll(['adventure', 'fantasy']));
    expect(item.ratings['mal']?.score, 9.1);
    expect(item.ratings['mal']?.votes, 100000);
    expect(item.region, CatalogRegion.unknown);
    expect(
        item.externalRefs, [const ExternalRef(namespace: 'mal', id: '52991')]);
    expect(page.nextCursor, isNotNull);
    expect(page.complete, isFalse);
    expect(page.locallyEvaluated, contains('genres'));
  });

  test('Jikan limiter enforces rolling three-per-second and sixty-per-minute',
      () async {
    var now = DateTime.utc(2026, 7, 16);
    final waits = <Duration>[];
    final admitted = <DateTime>[];
    final limiter = JikanRequestLimiter(
      now: () => now,
      delay: (duration) async {
        waits.add(duration);
        now = now.add(duration);
      },
    );

    for (var index = 0; index < 61; index++) {
      await limiter.acquire();
      admitted.add(now);
    }

    expect(waits, isNotEmpty);
    for (final instant in admitted) {
      final inSecond = admitted.where(
        (candidate) =>
            !candidate.isAfter(instant) &&
            candidate.isAfter(instant.subtract(const Duration(seconds: 1))),
      );
      final inMinute = admitted.where(
        (candidate) =>
            !candidate.isAfter(instant) &&
            candidate.isAfter(instant.subtract(const Duration(minutes: 1))),
      );
      expect(inSecond.length, lessThanOrEqualTo(3));
      expect(inMinute.length, lessThanOrEqualTo(60));
    }
    expect(now, DateTime.utc(2026, 7, 16, 0, 1));
  });

  test('identical in-flight Jikan requests share one network call and permit',
      () async {
    final response = Completer<Object?>();
    final limiter = _CountingLimiter();
    var calls = 0;
    final provider = JikanCatalogProvider(
      getJson: (uri, headers) {
        calls++;
        return response.future;
      },
      limiter: limiter,
    );

    final first = provider.query(const CatalogQuery(text: 'Frieren'));
    final second = provider.query(const CatalogQuery(text: 'Frieren'));
    await Future<void>.delayed(Duration.zero);

    expect(calls, 1);
    expect(limiter.calls, 1);
    response.complete({
      'pagination': {
        'last_visible_page': 1,
        'has_next_page': false,
        'current_page': 1,
      },
      'data': const [],
    });
    expect(await first, same(await second));
  });

  test(
      'adult-enabled Jikan query omits sfw instead of filtering for adult only',
      () async {
    Uri? captured;
    final provider = JikanCatalogProvider(
      getJson: (uri, headers) async {
        captured = uri;
        return {
          'pagination': {
            'last_visible_page': 1,
            'has_next_page': false,
            'current_page': 1,
          },
          'data': const [],
        };
      },
      limiter: _CountingLimiter(),
    );

    await provider.query(const CatalogQuery(includeAdult: true));

    expect(captured!.queryParameters.containsKey('sfw'), isFalse);
  });
}

class _CountingLimiter implements CatalogRequestLimiter {
  int calls = 0;

  @override
  Future<void> acquire() async {
    calls++;
  }
}
