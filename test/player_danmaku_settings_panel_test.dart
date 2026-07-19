import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weila/pages/player/widgets/player_danmaku_settings_panel.dart';

void main() {
  testWidgets('弹幕设置面板展示当前参数并支持切换显示状态', (tester) async {
    var toggled = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: PlayerDanmakuSettingsPanel(
              visible: true,
              opacity: 0.8,
              area: 0.5,
              speed: 1.5,
              fontScale: 1.2,
              onToggleVisible: () => toggled = true,
              onOpacityChanged: (_) {},
              onAreaChanged: (_) {},
              onSpeedChanged: (_) {},
              onFontScaleChanged: (_) {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('弹幕设置'), findsOneWidget);
    expect(find.text('显示'), findsOneWidget);
    expect(find.text('不透明度'), findsOneWidget);
    expect(find.text('80%'), findsOneWidget);
    expect(find.text('显示区域'), findsOneWidget);
    expect(find.text('50%'), findsOneWidget);
    expect(find.text('滚动速度'), findsOneWidget);
    expect(find.text('1.5x'), findsOneWidget);
    expect(find.text('字号'), findsOneWidget);
    expect(find.text('1.2x'), findsOneWidget);

    await tester.tap(find.text('显示'));
    expect(toggled, isTrue);
  });
}
