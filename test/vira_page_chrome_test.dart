import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weila/theme/app_theme.dart';
import 'package:weila/widgets/editorial_section_header.dart';
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
