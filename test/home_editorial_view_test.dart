import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weila/pages/home/home_editorial_view.dart';
import 'package:weila/theme/app_theme.dart';
import 'package:weila/widgets/artwork_components.dart';

void main() {
  final animeItems = List.generate(
    8,
    (index) => <String, dynamic>{
      'name': '动画作品 ${index + 1}',
      'cover': null,
      'score': 8.0 + index / 10,
      'status': index.isEven ? '更新至第${index + 2}集' : '放送中',
      'genres': ['奇幻', '青春'],
      'url': 'anime:$index',
    },
  );

  final continueStories = [
    const HomeContinueStory(
      title: '上次看到的故事',
      coverUrl: null,
      progressLabel: '看到第 6 集',
      updatedLabel: '昨天',
      animeUrl: 'continue:1',
    ),
  ];

  testWidgets('首页呈现天空日记与杂志式六段信息结构', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: HomeEditorialView(
            latestItems: animeItems,
            seasonalItems: animeItems,
            trendingItems: animeItems,
            continueStories: continueStories,
            onOpenAnime: (_) {},
            onOpenContinue: (_) {},
            onRetry: () {},
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('home-diary-strip')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-editorial-hero')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-continue')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-today')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-seasonal')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-ranking')), findsOneWidget);

    expect(find.text('接着上次的故事'), findsOneWidget);
    expect(find.text('今日放送'), findsOneWidget);
    expect(find.text('本季选片'), findsOneWidget);
    expect(find.text('本周上升榜'), findsOneWidget);
  });

  testWidgets('首页核心操作可点击且使用桌面指针', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    Map<String, dynamic>? openedAnime;
    HomeContinueStory? openedContinue;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: HomeEditorialView(
            latestItems: animeItems,
            seasonalItems: animeItems,
            trendingItems: animeItems,
            continueStories: continueStories,
            onOpenAnime: (item) => openedAnime = item,
            onOpenContinue: (item) => openedContinue = item,
            onRetry: () {},
          ),
        ),
      ),
    );

    await tester.tap(find.text('查看详情').first);
    await tester.tap(find.text('继续观看').first);
    expect(openedAnime, animeItems.first);
    expect(openedContinue, continueStories.first);

    final pointerRegions = tester.widgetList<MouseRegion>(
      find.byWidgetPredicate(
        (widget) =>
            widget is MouseRegion && widget.cursor == SystemMouseCursors.click,
      ),
    );
    expect(pointerRegions.length, greaterThanOrEqualTo(10));
  });

  testWidgets('今日放送五项使用稳定柔光卡片并打开正确项目', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    Map<String, dynamic>? openedAnime;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: HomeEditorialView(
            latestItems: animeItems,
            seasonalItems: animeItems,
            trendingItems: animeItems,
            continueStories: continueStories,
            onOpenAnime: (item) => openedAnime = item,
            onOpenContinue: (_) {},
            onRetry: () {},
          ),
        ),
      ),
    );

    for (var index = 0; index < 5; index += 1) {
      expect(
        find.byKey(ValueKey('artwork-card-today-$index')),
        findsOneWidget,
      );
      expect(
        find.byKey(ValueKey('artwork-card-action-today-$index')),
        findsOneWidget,
      );
    }

    final action = find.byKey(const ValueKey('artwork-card-action-today-3'));
    await tester.ensureVisible(action);
    await tester.pump();
    await tester.tap(action);
    expect(openedAnime, same(animeItems[3]));
  });

  testWidgets('今日放送窄屏横向列表沿用相同卡片编号', (tester) async {
    await tester.binding.setSurfaceSize(const Size(960, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: HomeEditorialView(
            latestItems: animeItems,
            seasonalItems: animeItems,
            trendingItems: animeItems,
            continueStories: continueStories,
            onOpenAnime: (_) {},
            onOpenContinue: (_) {},
            onRetry: () {},
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('artwork-card-today-0')),
      findsOneWidget,
    );
    final todayScrollable = find.descendant(
      of: find.byKey(const ValueKey('home-today')),
      matching: find.byType(Scrollable),
    );
    expect(todayScrollable, findsOneWidget);

    tester.state<ScrollableState>(todayScrollable).position.jumpTo(
          tester
              .state<ScrollableState>(todayScrollable)
              .position
              .maxScrollExtent,
        );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('artwork-card-today-4')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('artwork-card-action-today-4')),
      findsOneWidget,
    );
  });

  testWidgets('今日放送卡片悬停时轻推封面并在离开后复位', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: HomeEditorialView(
            latestItems: animeItems,
            seasonalItems: animeItems,
            trendingItems: animeItems,
            continueStories: continueStories,
            onOpenAnime: (_) {},
            onOpenContinue: (_) {},
            onRetry: () {},
          ),
        ),
      ),
    );

    const cardKey = ValueKey('artwork-card-today-0');
    const coverKey = ValueKey('today-cover-scale-0');
    await tester.ensureVisible(find.byKey(cardKey));
    await tester.pump();
    expect(tester.widget<AnimatedScale>(find.byKey(coverKey)).scale, 1);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.byKey(cardKey)));
    await tester.pump();

    expect(tester.widget<AnimatedScale>(find.byKey(coverKey)).scale, 1.025);

    await mouse.moveTo(const Offset(1400, 20));
    await tester.pump();

    expect(tester.widget<AnimatedScale>(find.byKey(coverKey)).scale, 1);
  });

  testWidgets('今日放送紧凑卡在封面槽内裁切悬停缩放', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: HomeEditorialView(
            latestItems: animeItems,
            seasonalItems: animeItems,
            trendingItems: animeItems,
            continueStories: continueStories,
            onOpenAnime: (_) {},
            onOpenContinue: (_) {},
            onRetry: () {},
          ),
        ),
      ),
    );

    final clip = find.byKey(const ValueKey('today-cover-clip-1'));
    final cover = find.byKey(const ValueKey('today-cover-scale-1'));

    expect(clip, findsOneWidget);
    expect(tester.widget<ClipRect>(clip).clipBehavior, Clip.hardEdge);
    expect(find.descendant(of: clip, matching: cover), findsOneWidget);
    expect(tester.getSize(clip).width, 104);
  });

  testWidgets('今日放送在减少动态效果时不缩放封面或抬升卡片', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: HomeEditorialView(
              latestItems: animeItems,
              seasonalItems: animeItems,
              trendingItems: animeItems,
              continueStories: continueStories,
              onOpenAnime: (_) {},
              onOpenContinue: (_) {},
              onRetry: () {},
            ),
          ),
        ),
      ),
    );

    const cardKey = ValueKey('artwork-card-today-0');
    const coverKey = ValueKey('today-cover-scale-0');
    await tester.ensureVisible(find.byKey(cardKey));
    await tester.pump();

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.byKey(cardKey)));
    await tester.pump();

    final card = tester.widget<AnimatedContainer>(find.byKey(cardKey));
    expect(card.duration, Duration.zero);
    expect(card.transform?.getTranslation().y, 0);
    expect(tester.widget<AnimatedScale>(find.byKey(coverKey)).scale, 1);
  });

  testWidgets('本周主映点击数字后切换番剧并打开当前项目', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    Map<String, dynamic>? openedAnime;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: HomeEditorialView(
            latestItems: animeItems,
            seasonalItems: animeItems,
            trendingItems: animeItems,
            continueStories: continueStories,
            onOpenAnime: (item) => openedAnime = item,
            onOpenContinue: (_) {},
            onRetry: () {},
          ),
        ),
      ),
    );

    expect(find.text('今天，继续\n动画作品 1。'), findsOneWidget);
    expect(find.text('镜头 01 / 04'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('home-hero-selector-1')),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('今天，继续\n动画作品 2。'), findsOneWidget);
    expect(find.text('镜头 02 / 04'), findsOneWidget);

    final detailsButton = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, '查看详情').last,
    );
    detailsButton.onPressed!();
    expect(openedAnime, animeItems[1]);
  });

  testWidgets('本周主映会自动切换到下一项', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: HomeEditorialView(
            latestItems: animeItems,
            seasonalItems: animeItems,
            trendingItems: animeItems,
            continueStories: continueStories,
            onOpenAnime: (_) {},
            onOpenContinue: (_) {},
            onRetry: () {},
          ),
        ),
      ),
    );

    expect(find.text('今天，继续\n动画作品 1。'), findsOneWidget);

    await tester.pump(const Duration(seconds: 7));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('今天，继续\n动画作品 2。'), findsOneWidget);
  });

  testWidgets('首页使用层叠续看、完整海报轨道与环境背景', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final stories = List.generate(
      5,
      (index) => HomeContinueStory(
        title: '续看故事 ${index + 1}',
        coverUrl: null,
        progressLabel: '看到第 ${index + 1} 集',
        updatedLabel: '今天',
        animeUrl: 'continue:$index',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: HomeEditorialView(
            latestItems: animeItems,
            seasonalItems: animeItems,
            trendingItems: animeItems,
            continueStories: stories,
            onOpenAnime: (_) {},
            onOpenContinue: (_) {},
            onRetry: () {},
          ),
        ),
      ),
    );

    final stack = tester.widget<LayeredArtworkStack>(
      find.byType(LayeredArtworkStack),
    );
    final rail = tester.widget<PosterRail>(find.byType(PosterRail));

    expect(stack.items, hasLength(5));
    expect(rail.items, hasLength(animeItems.length));
    expect(
      find.byKey(const ValueKey('home-ambient-hero')),
      findsOneWidget,
    );
  });

  testWidgets('首页加载失败时使用统一中文状态', (tester) async {
    var retried = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: HomeEditorialView(
            latestItems: const [],
            seasonalItems: const [],
            trendingItems: const [],
            continueStories: const [],
            errorMessage: '网络暂时不可用',
            onOpenAnime: (_) {},
            onOpenContinue: (_) {},
            onRetry: () => retried = true,
          ),
        ),
      ),
    );

    expect(find.text('今天的放映单还没送达'), findsOneWidget);
    await tester.tap(find.text('重新加载'));
    expect(retried, isTrue);
  });

  testWidgets('首页在 960、1280、1600 宽度下无布局溢出', (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));

    for (final width in [960.0, 1280.0, 1600.0]) {
      await tester.binding.setSurfaceSize(Size(width, 1000));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: HomeEditorialView(
              latestItems: animeItems,
              seasonalItems: animeItems,
              trendingItems: animeItems,
              continueStories: continueStories,
              onOpenAnime: (_) {},
              onOpenContinue: (_) {},
              onRetry: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        tester.takeException(),
        isNull,
        reason: '$width 宽度不应产生布局异常',
      );
      expect(find.byType(PosterRail), findsOneWidget);
    }
  });
}
