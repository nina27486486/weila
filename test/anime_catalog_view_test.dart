import 'package:flutter/gestures.dart';
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
      'score': index == 7 ? null : 8.2,
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
    await tester.tap(
      find.byKey(const ValueKey('artwork-card-action-catalog-0')),
    );
    expect(selectedSource, 'ffzy');
    expect(opened, items.first);
  });

  testWidgets('目录作品统一使用共享玻璃卡片、徽章和主操作', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    Map<String, dynamic>? opened;
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: AnimeCatalogView(
            title: '分类浏览',
            description: '从片库寻找下一段故事。',
            items: items,
            onOpenAnime: (item) => opened = item,
            onRetry: () {},
          ),
        ),
      ),
    );

    for (var index = 0; index < items.length; index += 1) {
      expect(
        find.byKey(ValueKey('artwork-card-catalog-$index')),
        findsOneWidget,
      );
      expect(
        find.byKey(ValueKey('artwork-card-action-catalog-$index')),
        findsOneWidget,
      );
      expect(
        find.byKey(ValueKey('catalog-rank-$index')),
        findsOneWidget,
      );
    }
    for (var index = 0; index < items.length - 1; index += 1) {
      expect(
        find.byKey(ValueKey('catalog-score-$index')),
        findsOneWidget,
      );
    }
    expect(find.byKey(const ValueKey('catalog-score-7')), findsNothing);
    expect(
      find.bySemanticsLabel('打开第1部作品，片库作品 1'),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel(RegExp('catalog:')), findsNothing);

    await tester.tap(
      find.byKey(const ValueKey('artwork-card-action-catalog-0')),
    );
    expect(opened, items.first);
    semantics.dispose();
  });

  testWidgets('目录网格为抬升预留空间并保持原卡体高度与可见行距', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: AnimeCatalogView(
            title: '分类浏览',
            description: '从片库寻找下一段故事。',
            items: items,
            onOpenAnime: (_) {},
            onRetry: () {},
          ),
        ),
      ),
    );

    final grid = tester.widget<SliverGrid>(find.byType(SliverGrid));
    final delegate =
        grid.gridDelegate as SliverGridDelegateWithMaxCrossAxisExtent;
    expect(delegate.maxCrossAxisExtent, 218);
    expect(delegate.crossAxisSpacing, 16);
    expect(delegate.mainAxisExtent, 332);
    expect(delegate.mainAxisSpacing, 16);

    final firstRowCard = tester.getRect(
      find.byKey(const ValueKey('artwork-card-catalog-0')),
    );
    final secondRowCard = tester.getRect(
      find.byKey(const ValueKey('artwork-card-catalog-6')),
    );
    expect(firstRowCard.height, 326);
    expect(secondRowCard.height, 326);
    expect(secondRowCard.top - firstRowCard.bottom, 22);
  });

  testWidgets('目录卡悬停时只在封面槽内缩放并在离开后复位', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: AnimeCatalogView(
            title: '分类浏览',
            description: '从片库寻找下一段故事。',
            items: items,
            onOpenAnime: (_) {},
            onRetry: () {},
          ),
        ),
      ),
    );

    const cardKey = ValueKey('artwork-card-catalog-0');
    const clipKey = ValueKey('catalog-cover-clip-0');
    const coverKey = ValueKey('catalog-cover-scale-0');
    final clip = find.byKey(clipKey);
    final cover = find.byKey(coverKey);
    expect(clip, findsOneWidget);
    expect(tester.widget<ClipRect>(clip).clipBehavior, Clip.hardEdge);
    expect(find.descendant(of: clip, matching: cover), findsOneWidget);
    expect(tester.widget<AnimatedScale>(cover).scale, 1);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.byKey(cardKey)));
    await tester.pump();
    expect(tester.widget<AnimatedScale>(cover).scale, 1.025);

    await mouse.moveTo(const Offset(1240, 20));
    await tester.pump();
    expect(tester.widget<AnimatedScale>(cover).scale, 1);
  });

  testWidgets('目录卡在减少动态效果时不缩放封面或抬升卡片', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: AnimeCatalogView(
              title: '分类浏览',
              description: '从片库寻找下一段故事。',
              items: items,
              onOpenAnime: (_) {},
              onRetry: () {},
            ),
          ),
        ),
      ),
    );

    const cardKey = ValueKey('artwork-card-catalog-0');
    const coverKey = ValueKey('catalog-cover-scale-0');
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.byKey(cardKey)));
    await tester.pump();

    final surface = tester.widget<AnimatedContainer>(find.byKey(cardKey));
    expect(surface.duration, Duration.zero);
    expect(surface.transform?.getTranslation().y, 0);
    expect(tester.widget<AnimatedScale>(find.byKey(coverKey)).scale, 1);
  });

  testWidgets('目录网格在三种宽度的深色主题下保持稳定', (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));

    for (final width in [960.0, 1280.0, 1600.0]) {
      await tester.binding.setSurfaceSize(Size(width, 900));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: AnimeCatalogView(
              title: '分类浏览',
              description: '从类型、片源和放送状态里寻找下一段故事。',
              items: items,
              onOpenAnime: (_) {},
              onRetry: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
          find.byKey(const ValueKey('catalog-results-grid')), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('目录卡保留超长标题单行省略并兼容空封面', (tester) async {
    await tester.binding.setSurfaceSize(const Size(960, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const longTitle = '这是一部标题特别特别长但仍然要维持目录卡片排版完整的动画作品';
    final edgeItems = [
      <String, dynamic>{
        'name': longTitle,
        'cover': null,
        'score': 9.1,
        'status': '连载中',
        'genres': ['奇幻'],
      },
      <String, dynamic>{
        'name': '空地址封面',
        'cover': '',
        'score': null,
        'status': '已完结',
        'genres': const <String>[],
      },
    ];

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: AnimeCatalogView(
            title: '分类浏览',
            description: '从片库寻找下一段故事。',
            items: edgeItems,
            onOpenAnime: (_) {},
            onRetry: () {},
          ),
        ),
      ),
    );

    final title = tester.widget<Text>(find.text(longTitle));
    expect(title.maxLines, 1);
    expect(title.overflow, TextOverflow.ellipsis);
    expect(
      find.byKey(const ValueKey('artwork-card-catalog-0')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('artwork-card-catalog-1')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
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
