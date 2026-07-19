import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weila/models/catalog/catalog_enums.dart';
import 'package:weila/models/catalog/catalog_values.dart';
import 'package:weila/pages/discover/anime_catalog_view.dart';
import 'package:weila/pages/discover/category_browse_page.dart';
import 'package:weila/services/catalog/catalog_repository.dart';
import 'package:weila/theme/app_theme.dart';

void main() {
  testWidgets('catalog defaults to discovery with common and more filters', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _CatalogRepository();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: CategoryBrowsePage(
          repository: repository,
          providerOptions: const [
            CatalogFilterOption(id: 'cms_test', label: '测试片源'),
          ],
        ),
      ),
    );
    await _pumpCatalog(tester);

    expect(find.text('发现动画'), findsOneWidget);
    expect(find.text('可播放片库'), findsOneWidget);
    expect(
      tester
          .widget<Semantics>(
            find.byKey(const ValueKey('catalog-mode-discovery')),
          )
          .properties
          .selected,
      isTrue,
    );
    for (final label in ['题材', '年份', '形态', '状态']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('季度'), findsNothing);
    expect(find.text('已加载 1 部'), findsOneWidget);
    expect(find.text('当前索引已覆盖'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('catalog-more-filters')));
    await tester.pump();
    for (final label in ['季度', '地区', '评分', '排序']) {
      expect(find.text(label), findsWidgets);
    }
    expect(find.text('片源'), findsNothing);
    expect(find.text('更新时间'), findsNothing);
  });

  testWidgets(
      'playable tab adds provider/update filters and removable summaries', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _CatalogRepository();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: CategoryBrowsePage(
          repository: repository,
          providerOptions: const [
            CatalogFilterOption(id: 'cms_test', label: '测试片源'),
          ],
        ),
      ),
    );
    await _pumpCatalog(tester);

    await tester.tap(find.byKey(const ValueKey('catalog-mode-playable')));
    await _pumpCatalog(tester);
    await tester.tap(find.byKey(const ValueKey('catalog-more-filters')));
    await tester.pump();

    expect(find.text('片源'), findsOneWidget);
    expect(find.text('更新时间'), findsOneWidget);
    expect(repository.queries.last.mode, CatalogMode.playable);

    await tester.tap(
      find.byKey(const ValueKey('catalog-filter-genres-fantasy')),
    );
    await _pumpCatalog(tester);
    await tester.ensureVisible(
      find.byKey(const ValueKey('catalog-filter-year-2024')),
    );
    await tester.tap(
      find.byKey(const ValueKey('catalog-filter-year-2024')),
    );
    await _pumpCatalog(tester);

    expect(
      find.byKey(const ValueKey('catalog-summary-genre-fantasy')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('catalog-summary-year')),
      findsOneWidget,
    );
    expect(repository.queries.last.genres, {'fantasy'});
    expect(repository.queries.last.year, 2024);

    final summary = find.byKey(
      const ValueKey('catalog-summary-genre-fantasy'),
    );
    await tester
        .tap(find.descendant(of: summary, matching: find.byIcon(Icons.close)));
    await _pumpCatalog(tester);
    expect(repository.queries.last.genres, isEmpty);
  });

  testWidgets('catalog remains stable at 960 1280 and 1600 with reduced motion',
      (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final width in [960.0, 1280.0, 1600.0]) {
      await tester.binding.setSurfaceSize(Size(width, 1000));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: CategoryBrowsePage(repository: _CatalogRepository()),
          ),
        ),
      );
      await _pumpCatalog(tester);

      expect(
        find.byKey(const ValueKey('catalog-results-grid')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    }
  });
}

Future<void> _pumpCatalog(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

class _CatalogRepository implements CatalogRepository {
  final List<CatalogQuery> queries = [];

  @override
  Future<CatalogPage> query(
    CatalogQuery query, {
    bool forceRefresh = false,
  }) async {
    queries.add(query);
    return CatalogPage(
      items: [
        CatalogContent(
          contentId: 'content-1',
          titles: const CatalogTitles(primary: '测试动画'),
          year: 2024,
          format: CatalogFormat.tv,
          status: CatalogStatus.airing,
          region: CatalogRegion.japan,
          genres: const {'fantasy', 'adventure'},
          ratings: const {
            'test': CatalogRating(score: 8.8, source: 'test'),
          },
          playableRefs: query.mode == CatalogMode.playable
              ? const [
                  PlayableRef(
                    providerId: 'cms_test',
                    sourceItemId: '42',
                    routeCount: 2,
                  ),
                ]
              : const [],
        ),
      ],
      coverage: CatalogQueryCoverage(
        modes: {query.mode},
        complete: true,
      ),
    );
  }

  @override
  Future<void> confirmPlayable(String contentId, PlayableRef ref) async {}

  @override
  Future<List<PlayableMatch>> findPlayable(String contentId) async => const [];

  @override
  Future<CatalogContent?> getById(String contentId) async => null;
}
