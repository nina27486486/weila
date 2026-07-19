import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:weila/models/catalog/catalog_enums.dart';
import 'package:weila/models/catalog/catalog_values.dart';
import 'package:weila/models/plugin.dart';
import 'package:weila/models/plugin_catalog.dart';
import 'package:weila/services/catalog/providers/catalog_provider.dart';
import 'package:weila/services/catalog/providers/cms_catalog_provider.dart';

void main() {
  test('CMS admits only structural playback and never requests media URLs',
      () async {
    final requests = <Uri>[];
    final provider = CmsCatalogProvider(
      plugin: _plugin(),
      getJson: (uri, headers) async {
        requests.add(uri);
        if (uri.queryParameters['ac'] == 'detail') {
          return {
            'list': [
              {
                'vod_id': '42',
                'vod_name': '结构可播放动画',
                'vod_sub': 'Structural Anime',
                'vod_class': '动作,奇幻,校园,冒险',
                'vod_year': '2024',
                'vod_area': '日本',
                'vod_score': '8.5',
                'vod_remarks': '已完结',
                'vod_time': '2026-07-16T08:00:00Z',
                'vod_play_from': r'lineA$$$lineB',
                'vod_play_url':
                    r'第1集$https://media-a.example/1.m3u8$$$第1集$https://media-b.example/1.m3u8',
              },
            ],
          };
        }
        return {
          'pagecount': '1',
          'total': '1',
          'list': [
            {
              'vod_id': '42',
              'vod_name': '结构可播放动画',
              'vod_class': '动作,奇幻,校园,冒险',
              'vod_year': '2024',
              'vod_area': '日本',
              'vod_score': '8.5',
              'vod_remarks': '已完结',
            },
          ],
        };
      },
    );

    final page = await provider.query(
      const CatalogQuery(
        mode: CatalogMode.playable,
        providerId: 'cms_test',
        genres: {'action', 'fantasy'},
        region: CatalogRegion.japan,
      ),
    );

    expect(requests, hasLength(2));
    expect(
      requests.every((uri) => uri.host == 'cms.example'),
      isTrue,
    );
    expect(requests.map((uri) => uri.queryParameters['ac']),
        ['videolist', 'detail']);
    expect(page.items, hasLength(1));
    final item = page.items.single;
    expect(
        item.genres, containsAll(['action', 'fantasy', 'school', 'adventure']));
    expect(item.playableRefs, [
      const PlayableRef(
        providerId: 'cms_test',
        sourceItemId: '42',
        routeCount: 2,
      ),
    ]);
    expect(item.toMap().toString(), isNot(contains('media-a.example')));
    expect(page.remotelyEvaluated, contains('region'));
    expect(page.locallyEvaluated, contains('genres'));
    expect(page.complete, isTrue);
  });

  test('CMS progressive scan advances at most three upstream pages per query',
      () async {
    final pages = <int>[];
    final provider = CmsCatalogProvider(
      plugin: _plugin(),
      getJson: (uri, headers) async {
        pages.add(int.parse(uri.queryParameters['pg']!));
        return {'pagecount': '10', 'total': '0', 'list': const []};
      },
    );

    final first = await provider.query(
      const CatalogQuery(mode: CatalogMode.playable, providerId: 'cms_test'),
    );
    final second = await provider.query(
      CatalogQuery(
        mode: CatalogMode.playable,
        providerId: 'cms_test',
        cursor: first.nextCursor,
      ),
    );

    expect(pages, [1, 2, 3, 4, 5, 6]);
    expect(first.scannedUpstreamPages, 3);
    expect(first.complete, isFalse);
    expect(first.nextCursor, isNotNull);
    expect(second.complete, isFalse);
  });

  test('CMS resolves details with an ordered maximum concurrency of three',
      () async {
    final completers = <Completer<Object?>>[];
    var active = 0;
    var maxActive = 0;
    final provider = CmsCatalogProvider(
      plugin: _plugin(),
      getJson: (uri, headers) {
        if (uri.queryParameters['ac'] == 'videolist') {
          return Future.value({
            'pagecount': 1,
            'total': 5,
            'list': [
              for (var id = 1; id <= 5; id++)
                {'vod_id': '$id', 'vod_name': '作品$id'},
            ],
          });
        }
        active++;
        if (active > maxActive) maxActive = active;
        final id = uri.queryParameters['ids']!;
        final completer = Completer<Object?>();
        completers.add(completer);
        return completer.future.whenComplete(() => active--).then((_) => {
              'list': [
                {
                  'vod_id': id,
                  'vod_name': '作品$id',
                  'vod_play_from': 'line',
                  'vod_play_url': '第1集\$https://media.example/$id.m3u8',
                },
              ],
            });
      },
    );

    final future = provider.query(
      const CatalogQuery(mode: CatalogMode.playable, providerId: 'cms_test'),
    );
    await _waitUntil(() => completers.length == 3);
    expect(active, 3);
    expect(maxActive, 3);

    for (final completer in List<Completer<Object?>>.from(completers)) {
      completer.complete(null);
    }
    await _waitUntil(() => completers.length == 5);
    for (final completer in completers.where((entry) => !entry.isCompleted)) {
      completer.complete(null);
    }
    final page = await future;

    expect(maxActive, 3);
    expect(
      page.items.map((item) => item.playableRefs.single.sourceItemId),
      ['1', '2', '3', '4', '5'],
    );
  });

  test('CMS rejects disabled, legacy, and mismatched exact providers',
      () async {
    expect(
      () => CmsCatalogProvider(plugin: _plugin(enabled: false)),
      throwsA(isA<CatalogProviderUnavailableException>()),
    );
    expect(
      () => CmsCatalogProvider(plugin: _plugin(catalog: null)),
      throwsA(isA<CatalogProviderUnavailableException>()),
    );
    var calls = 0;
    final provider = CmsCatalogProvider(
      plugin: _plugin(),
      getJson: (uri, headers) async {
        calls++;
        return const {};
      },
    );

    await expectLater(
      provider.query(
        const CatalogQuery(
          mode: CatalogMode.playable,
          providerId: 'another_provider',
        ),
      ),
      throwsA(isA<CatalogProviderUnavailableException>()),
    );
    expect(calls, 0);
  });

  test('CMS rechecks explicit adult markers found only in detail data',
      () async {
    var detailCalls = 0;
    final provider = CmsCatalogProvider(
      plugin: _plugin(),
      getJson: (uri, headers) async {
        if (uri.queryParameters['ac'] == 'detail') {
          detailCalls++;
          return {
            'list': [
              {
                'vod_id': '18',
                'vod_name': '成人条目',
                'vod_class': '里番',
                'vod_play_from': 'line',
                'vod_play_url': r'第1集$https://media.example/18.m3u8',
              },
            ],
          };
        }
        return {
          'pagecount': 1,
          'total': 1,
          'list': [
            {'vod_id': '18', 'vod_name': '普通标题'},
          ],
        };
      },
    );

    final page = await provider.query(
      const CatalogQuery(mode: CatalogMode.playable, providerId: 'cms_test'),
    );

    expect(page.items, isEmpty);
    expect(detailCalls, 1);
  });
}

Plugin _plugin({
  bool enabled = true,
  PluginCatalogConfig? catalog = const PluginCatalogConfig(
    kind: 'mac_cms_v1',
    categories: [
      PluginCatalogCategory(
        id: '10',
        label: '日本动漫',
        facets: {'region': 'jp'},
      ),
    ],
    sorts: {'updated', 'score', 'popularity'},
  ),
}) {
  return Plugin(
    api: 'cms_test',
    name: 'CMS Test',
    baseUrl: 'https://cms.example',
    searchURL: 'https://cms.example/api.php/provide/vod/',
    searchList: 'list',
    searchName: 'vod_name',
    searchResult: 'vod_id',
    chapterRoads: '',
    chapterResult: '',
    userAgent: 'Weila Test',
    enabled: enabled,
    catalog: catalog,
  );
}

Future<void> _waitUntil(bool Function() condition) async {
  for (var attempt = 0; attempt < 100 && !condition(); attempt++) {
    await Future<void>.delayed(Duration.zero);
  }
  expect(condition(), isTrue);
}
