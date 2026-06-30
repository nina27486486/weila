import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weila/pages/discover/anime_catalog_view.dart';
import 'package:weila/theme/app_theme.dart';

void main() {
  final items = List.generate(
    8,
    (index) => <String, dynamic>{
      'name': '片库作品 ${index + 1}',
      'cover': null,
      'score': 8.2,
      'status': '更新至第 8 集',
      'genres': ['奇幻', '冒险'],
      'url': 'catalog:$index',
    },
  );

  testWidgets('编辑式片库展示来源、栏目、类型与结果网格', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    String? selectedSource;
    Map<String, dynamic>? opened;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: AnimeCatalogView(
            title: '分类浏览',
            description: '从类型、片源和放送状态里寻找下一段故事。',
            sourceOptions: const [
              CatalogFilterOption(id: 'sakura', label: '樱花动漫'),
              CatalogFilterOption(id: 'ffzy', label: '非凡资源'),
            ],
            selectedSourceId: 'sakura',
            onSourceSelected: (value) => selectedSource = value,
            categoryOptions: const [
              CatalogFilterOption(id: 'anime', label: '日本动漫'),
              CatalogFilterOption(id: 'movie', label: '动画电影'),
            ],
            selectedCategoryId: 'anime',
            onCategorySelected: (_) {},
            genreOptions: const [
              CatalogFilterOption(id: 'all', label: '全部'),
              CatalogFilterOption(id: 'fantasy', label: '奇幻'),
            ],
            selectedGenreId: 'all',
            onGenreSelected: (_) {},
            items: items,
            onOpenAnime: (item) => opened = item,
            onRetry: () {},
          ),
        ),
      ),
    );

    expect(find.text('分类浏览'), findsOneWidget);
    expect(find.text('片源'), findsOneWidget);
    expect(find.text('栏目'), findsOneWidget);
    expect(find.text('类型'), findsOneWidget);
    expect(find.byKey(const ValueKey('catalog-results-grid')), findsOneWidget);

    await tester.tap(find.text('非凡资源'));
    await tester.tap(find.text('片库作品 1'));
    expect(selectedSource, 'ffzy');
    expect(opened, items.first);
  });

  testWidgets('片库错误状态提供统一重试动作', (tester) async {
    var retried = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: AnimeCatalogView(
            title: '番剧',
            description: '按片源整理的长篇动画。',
            items: const [],
            errorMessage: '加载失败，请检查网络',
            onOpenAnime: (_) {},
            onRetry: () => retried = true,
          ),
        ),
      ),
    );

    expect(find.text('片库暂时没有回应'), findsOneWidget);
    await tester.tap(find.text('重新加载'));
    expect(retried, isTrue);
  });
}
