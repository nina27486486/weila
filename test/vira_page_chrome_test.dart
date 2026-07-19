import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weila/theme/app_theme.dart';
import 'package:weila/widgets/editorial_section_header.dart';
import 'package:weila/widgets/liquid_glass_surface.dart';
import 'package:weila/widgets/vira_page_chrome.dart';
import 'package:weila/widgets/vira_state_view.dart';
import 'package:weila/widgets/vira_text_tabs.dart';

void main() {
  testWidgets('全局刊头展示五个稳定入口与中文工具提示', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    ViraDestination? selected;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: ViraPageScaffold(
          activeDestination: ViraDestination.home,
          onDestinationSelected: (value) => selected = value,
          onSearch: () {},
          onThemeToggle: () {},
          onProfile: () {},
          child: const Text('页面内容'),
        ),
      ),
    );

    expect(find.text('首页'), findsOneWidget);
    expect(find.text('发现'), findsOneWidget);
    expect(find.text('追番'), findsOneWidget);
    expect(find.text('资料库'), findsOneWidget);
    expect(find.text('下载'), findsOneWidget);
    expect(
        find.byKey(const ValueKey('vira-nav-indicator-home')), findsOneWidget);
    expect(find.byTooltip('搜索'), findsOneWidget);
    expect(find.byTooltip('切换主题'), findsOneWidget);
    expect(find.byTooltip('个人与设置'), findsOneWidget);
    expect(find.text('页面内容'), findsOneWidget);

    await tester.tap(find.text('发现'));
    await tester.pump();
    expect(selected, ViraDestination.discover);
  });

  testWidgets('刊头交互入口使用桌面点击指针', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: ViraPageScaffold(
          activeDestination: ViraDestination.library,
          onDestinationSelected: (_) {},
          onSearch: () {},
          onThemeToggle: () {},
          onProfile: () {},
          child: const SizedBox(),
        ),
      ),
    );

    final pointerRegions = tester.widgetList<MouseRegion>(
      find.byWidgetPredicate(
        (widget) =>
            widget is MouseRegion && widget.cursor == SystemMouseCursors.click,
      ),
    );

    expect(pointerRegions.length, greaterThanOrEqualTo(8));
  });

  testWidgets('刊头使用玻璃导航轨道、选中镜片与玻璃工具组', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: ViraPageScaffold(
          activeDestination: ViraDestination.following,
          onDestinationSelected: (_) {},
          onSearch: () {},
          onThemeToggle: () {},
          onProfile: () {},
          child: const SizedBox(),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('vira-navigation-glass')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('vira-nav-lens-following')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('vira-tools-glass')),
      findsOneWidget,
    );
    expect(find.byType(LiquidGlassSurface), findsNWidgets(2));
  });

  testWidgets('导航和工具入口可以获得键盘焦点并触发回调', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    ViraDestination? selected;
    var searched = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: ViraPageScaffold(
          activeDestination: ViraDestination.library,
          onDestinationSelected: (value) => selected = value,
          onSearch: () => searched = true,
          onThemeToggle: () {},
          onProfile: () {},
          child: const SizedBox(),
        ),
      ),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(
      find.byKey(const ValueKey('vira-nav-focus-home')),
      findsOneWidget,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(selected, ViraDestination.home);

    for (var index = 0; index < 5; index++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    }
    await tester.pump();
    expect(
      find.byKey(const ValueKey('vira-tool-focus-search')),
      findsOneWidget,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    expect(searched, isTrue);
  });

  testWidgets('玻璃高光循环移动并在减少动态效果时停用', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    Widget buildChrome({required bool disableAnimations}) {
      return MaterialApp(
        theme: AppTheme.lightTheme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            disableAnimations: disableAnimations,
          ),
          child: child!,
        ),
        home: ViraPageScaffold(
          activeDestination: ViraDestination.home,
          onDestinationSelected: (_) {},
          onSearch: () {},
          onThemeToggle: () {},
          onProfile: () {},
          child: const SizedBox(),
        ),
      );
    }

    await tester.pumpWidget(buildChrome(disableAnimations: false));
    final movingBefore = tester
        .widget<LiquidGlassSurface>(
          find.byKey(const ValueKey('vira-navigation-glass')),
        )
        .motionProgress;
    await tester.pump(const Duration(seconds: 2));
    final movingAfter = tester
        .widget<LiquidGlassSurface>(
          find.byKey(const ValueKey('vira-navigation-glass')),
        )
        .motionProgress;
    expect(movingAfter, isNot(movingBefore));

    await tester.pumpWidget(buildChrome(disableAnimations: true));
    final pausedBefore = tester
        .widget<LiquidGlassSurface>(
          find.byKey(const ValueKey('vira-navigation-glass')),
        )
        .motionProgress;
    await tester.pump(const Duration(seconds: 2));
    final pausedAfter = tester
        .widget<LiquidGlassSurface>(
          find.byKey(const ValueKey('vira-navigation-glass')),
        )
        .motionProgress;
    expect(pausedAfter, pausedBefore);
  });

  testWidgets('窄屏切换为紧凑玻璃导航且保留工具入口', (tester) async {
    await tester.binding.setSurfaceSize(const Size(880, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: ViraPageScaffold(
          activeDestination: ViraDestination.following,
          onDestinationSelected: (_) {},
          onSearch: () {},
          onThemeToggle: () {},
          onProfile: () {},
          child: const SizedBox(),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('vira-compact-navigation-glass')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('vira-navigation-glass')),
      findsNothing,
    );
    expect(find.byTooltip('搜索'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final width in [960.0, 1280.0, 1600.0]) {
    testWidgets('刊头在 ${width.toInt()} 宽度下无布局溢出', (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: ViraPageScaffold(
            activeDestination: ViraDestination.downloads,
            onDestinationSelected: (_) {},
            onSearch: () {},
            onThemeToggle: () {},
            onProfile: () {},
            child: const SizedBox(),
          ),
        ),
      );

      expect(
        find.byKey(const ValueKey('vira-navigation-glass')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('编辑式章节标题与文字索引保持轻量层级', (tester) async {
    var actionTapped = false;
    var selectedIndex = -1;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: Column(
            children: [
              EditorialSectionHeader(
                chapter: '镜头 02',
                title: '接着上次的故事',
                subtitle: '不催促，只替你记住停下的位置',
                actionLabel: '全部记录',
                onAction: () => actionTapped = true,
              ),
              ViraTextTabs(
                labels: const ['全部', '番剧', '剧场版'],
                selectedIndex: 1,
                onSelected: (value) => selectedIndex = value,
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('镜头 02'), findsOneWidget);
    expect(find.text('接着上次的故事'), findsOneWidget);
    expect(find.byKey(const ValueKey('vira-tab-indicator-1')), findsOneWidget);

    await tester.tap(find.text('全部记录'));
    await tester.tap(find.text('剧场版'));
    expect(actionTapped, isTrue);
    expect(selectedIndex, 2);
  });

  testWidgets('共享状态视图提供中文说明与重试操作', (tester) async {
    var retried = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: ViraStateView.error(
            title: '画面暂时没有抵达',
            message: '请检查网络或稍后重试。',
            onRetry: () => retried = true,
          ),
        ),
      ),
    );

    expect(find.text('画面暂时没有抵达'), findsOneWidget);
    expect(find.text('重新加载'), findsOneWidget);
    await tester.tap(find.text('重新加载'));
    expect(retried, isTrue);
  });
}
