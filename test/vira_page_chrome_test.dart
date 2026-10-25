import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weila/platform/app_capabilities.dart';
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
    expect(
        find.byKey(const ValueKey('vira-brand-mascot-badge')), findsOneWidget);
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

  testWidgets('中屏直接展示紧凑顶部导航且保留工具入口', (tester) async {
    await tester.binding.setSurfaceSize(const Size(600, 800));
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
    expect(find.byType(PopupMenuButton<ViraDestination>), findsNothing);
    for (final label in ['首页', '发现', '追番', '资料库', '下载']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });

  for (final width in [360.0, 960.0, 1280.0, 1600.0]) {
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

      final navigationKey = width < 600
          ? const ValueKey('vira-bottom-navigation')
          : const ValueKey('vira-navigation-glass');
      expect(find.byKey(navigationKey), findsOneWidget);
      if (width >= 960) {
        expect(tester.getSize(find.byKey(navigationKey)), const Size(350, 52));
        expect(
          tester.getSize(find.byKey(const ValueKey('vira-tools-glass'))),
          const Size(126, 46),
        );
      }
      expect(tester.takeException(), isNull);
    });
  }

  for (final width in [360.0, 411.0, 599.0, 600.0, 839.0, 840.0]) {
    for (final dark in [false, true]) {
      testWidgets('Android外壳 $width 暗色=$dark 使用正确导航且等分可点击', (tester) async {
        await tester.binding.setSurfaceSize(Size(width, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        var selected = ViraDestination.home;
        var searched = false;
        var themed = false;
        var profiled = false;
        await tester.pumpWidget(
          _androidChrome(
            dark: dark,
            chromeBuilder: (setState) => ViraPageScaffold(
              activeDestination: selected,
              onDestinationSelected: (value) =>
                  setState(() => selected = value),
              onSearch: () => searched = true,
              onThemeToggle: () => themed = true,
              onProfile: () => profiled = true,
              child: const SizedBox.expand(key: ValueKey('content')),
            ),
          ),
        );

        final key = width < 600
            ? 'vira-bottom-navigation'
            : width < 840
                ? 'vira-compact-navigation-glass'
                : 'vira-navigation-glass';
        final navigation = find.byKey(ValueKey(key));
        expect(navigation, findsOneWidget);
        expect(find.byType(PopupMenuButton<ViraDestination>), findsNothing);
        expect(find.text('下载'), findsNothing);
        expect(find.byTooltip('搜索'), findsOneWidget);
        final content = tester.getRect(find.byKey(const ValueKey('content')));
        final navRect = tester.getRect(navigation);
        if (width < 600) {
          expect(navRect.top, greaterThanOrEqualTo(content.bottom));
        } else {
          expect(navRect.bottom, lessThanOrEqualTo(content.top));
          expect(find.byKey(const ValueKey('vira-bottom-navigation')),
              findsNothing);
        }

        final slots = [
          for (final name in ['home', 'discover', 'following', 'library'])
            tester.getRect(find.byKey(ValueKey('vira-nav-item-$name'))),
        ];
        for (var i = 0; i < slots.length; i++) {
          expect(slots[i].width, closeTo(slots.first.width, 0.01));
          if (i > 0) expect(slots[i].left, closeTo(slots[i - 1].right, 0.01));
          if (width < 840) expect(slots[i].height, greaterThanOrEqualTo(48));
        }
        for (final destination in ViraDestination.values.take(4)) {
          await tester
              .tap(find.byKey(ValueKey('vira-nav-item-${destination.name}')));
          await tester.pump(const Duration(milliseconds: 300));
          expect(selected, destination);
          expect(find.byKey(ValueKey('vira-nav-indicator-${destination.name}')),
              findsOneWidget);
          final node = tester.getSemantics(
              find.byKey(ValueKey('vira-nav-item-${destination.name}')));
          expect(node.flagsCollection.isSelected, Tristate.isTrue);
          expect(node.flagsCollection.isButton, isTrue);
          expect(
              node.label,
              switch (destination) {
                ViraDestination.home => '首页',
                ViraDestination.discover => '发现',
                ViraDestination.following => '追番',
                ViraDestination.library => '资料库',
                ViraDestination.downloads => '下载',
              });
        }
        await tester.tap(find.byTooltip('搜索'));
        await tester.tap(find.byTooltip('切换主题'));
        await tester.tap(find.byTooltip('个人与设置'));
        expect([searched, themed, profiled], everyElement(isTrue));
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final width in [360.0, 411.0, 600.0, 840.0]) {
    testWidgets('Android外壳 $width 无当前项且字体放大时避让安全区', (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_androidChrome(
        textScale: 2,
        padding: const EdgeInsets.fromLTRB(12, 24, 12, 34),
        chromeBuilder: (_) => ViraPageScaffold(
          activeDestination: null,
          onDestinationSelected: (_) {},
          onSearch: () {},
          onThemeToggle: () {},
          onProfile: () {},
          child: const SizedBox.expand(key: ValueKey('content')),
        ),
      ));
      for (final destination in ViraDestination.values.take(4)) {
        expect(find.byKey(ValueKey('vira-nav-indicator-${destination.name}')),
            findsNothing);
        final rect = tester
            .getRect(find.byKey(ValueKey('vira-nav-item-${destination.name}')));
        expect(rect.left, greaterThanOrEqualTo(12));
        expect(rect.right, lessThanOrEqualTo(width - 12));
        expect(rect.top, greaterThanOrEqualTo(24));
        expect(rect.bottom, lessThanOrEqualTo(800 - 34));
      }
      expect(tester.takeException(), isNull);
    });
  }

  for (final width in [600.0, 840.0]) {
    testWidgets('横屏 $width 大字号弹出键盘仍保留内容空间', (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 360));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_androidChrome(
        textScale: 2,
        padding: const EdgeInsets.only(top: 24),
        viewInsets: const EdgeInsets.only(bottom: 240),
        chromeBuilder: (_) => ViraPageScaffold(
          activeDestination: null,
          onDestinationSelected: (_) {},
          onSearch: () {},
          onThemeToggle: () {},
          onProfile: () {},
          child: const SizedBox.expand(key: ValueKey('content')),
        ),
      ));
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byKey(const ValueKey('content'))).height,
          greaterThan(0));
    });
  }

  testWidgets('跨断点切换保留内容状态且不重建页面业务', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_androidChrome(
      chromeBuilder: (_) => ViraPageScaffold(
        activeDestination: ViraDestination.home,
        onDestinationSelected: (_) {},
        onSearch: () {},
        onThemeToggle: () {},
        onProfile: () {},
        child: const _StatefulContent(),
      ),
    ));
    await tester.tap(find.text('计数 0'));
    await tester.pump();
    for (final width in [600.0, 840.0, 411.0]) {
      await tester.binding.setSurfaceSize(Size(width, 800));
      await tester.pump();
      expect(find.text('计数 1'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

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

Widget _androidChrome({
  required Widget Function(StateSetter) chromeBuilder,
  bool dark = false,
  double textScale = 1,
  EdgeInsets padding = EdgeInsets.zero,
  EdgeInsets viewInsets = EdgeInsets.zero,
}) {
  return AppCapabilitiesScope(
    capabilities: AppCapabilities.androidCompileBaseline,
    child: MaterialApp(
      theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
          padding: padding,
          viewPadding: padding,
          viewInsets: viewInsets,
          disableAnimations: true,
        ),
        child: child!,
      ),
      home: StatefulBuilder(builder: (_, setState) => chromeBuilder(setState)),
    ),
  );
}

class _StatefulContent extends StatefulWidget {
  const _StatefulContent();

  @override
  State<_StatefulContent> createState() => _StatefulContentState();
}

class _StatefulContentState extends State<_StatefulContent> {
  var count = 0;

  @override
  Widget build(BuildContext context) => Center(
        child: TextButton(
          onPressed: () => setState(() => count++),
          child: Text('计数 $count'),
        ),
      );
}
