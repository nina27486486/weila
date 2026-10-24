import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weila/pages/settings/widgets/settings_components.dart';
import 'package:weila/theme/app_theme.dart';

void main() {
  testWidgets('设置章节索引以轻量文字导航呈现五个分区', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1100, 500));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var selected = -1;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: SettingsChapterIndex(
            destinations: const [
              SettingsNavDestination(
                icon: Icons.palette_outlined,
                selectedIcon: Icons.palette,
                label: '外观',
              ),
              SettingsNavDestination(
                icon: Icons.play_circle_outline,
                selectedIcon: Icons.play_circle,
                label: '播放与弹幕',
              ),
              SettingsNavDestination(
                icon: Icons.extension_outlined,
                selectedIcon: Icons.extension,
                label: '数据源',
              ),
              SettingsNavDestination(
                icon: Icons.storage_outlined,
                selectedIcon: Icons.storage,
                label: '存储',
              ),
              SettingsNavDestination(
                icon: Icons.info_outline,
                selectedIcon: Icons.info,
                label: '关于',
              ),
            ],
            selectedIndex: 1,
            onSelected: (value) => selected = value,
          ),
        ),
      ),
    );

    expect(find.text('设置目录'), findsOneWidget);
    expect(find.byKey(const ValueKey('settings-chapter-1')), findsOneWidget);
    expect(find.text('关于'), findsOneWidget);
    await tester.tap(find.text('存储'));
    expect(selected, 3);

    final pointerRegions = tester.widgetList<MouseRegion>(
      find.byWidgetPredicate(
        (widget) =>
            widget is MouseRegion && widget.cursor == SystemMouseCursors.click,
      ),
    );
    expect(pointerRegions.length, greaterThanOrEqualTo(5));
  });

  testWidgets('设置侧栏版本卡使用看板娘品牌徽章', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: SettingsNavigation(
            destinations: const [
              SettingsNavDestination(
                icon: Icons.palette_outlined,
                selectedIcon: Icons.palette,
                label: '外观',
              ),
            ],
            selectedIndex: 0,
            version: '0.4.0',
            onSelected: (_) {},
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('settings-navigation-mascot-badge')),
      findsOneWidget,
    );
  });

  testWidgets('设置章节索引在 Pixel 7 窄屏宽度下无水平溢出', (tester) async {
    await tester.binding.setSurfaceSize(const Size(411, 914));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: SettingsChapterIndex(
            destinations: const [
              SettingsNavDestination(
                icon: Icons.palette_outlined,
                selectedIcon: Icons.palette,
                label: '外观',
              ),
              SettingsNavDestination(
                icon: Icons.play_circle_outline,
                selectedIcon: Icons.play_circle,
                label: '播放与弹幕',
              ),
              SettingsNavDestination(
                icon: Icons.extension_outlined,
                selectedIcon: Icons.extension,
                label: '数据源',
              ),
              SettingsNavDestination(
                icon: Icons.storage_outlined,
                selectedIcon: Icons.storage,
                label: '存储',
              ),
              SettingsNavDestination(
                icon: Icons.info_outline,
                selectedIcon: Icons.info,
                label: '关于',
              ),
            ],
            selectedIndex: 0,
            onSelected: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      tester.takeException(),
      isNull,
      reason: 'Pixel 7 窄屏章节索引不应产生 RenderFlex overflow',
    );
    for (final label in ['外观', '播放与弹幕', '数据源', '存储', '关于']) {
      expect(find.text(label), findsOneWidget);
    }
  });
}
