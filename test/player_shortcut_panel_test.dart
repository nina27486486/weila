import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weila/pages/player/widgets/player_shortcut_panel.dart';

void main() {
  testWidgets('快捷键面板展示常用操作并支持关闭', (tester) async {
    var closed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: PlayerShortcutPanel(onClose: () => closed = true),
          ),
        ),
      ),
    );

    expect(find.text('快捷键'), findsOneWidget);
    expect(find.text('空格'), findsOneWidget);
    expect(find.text('播放 / 暂停'), findsOneWidget);
    expect(find.text('Esc'), findsOneWidget);
    expect(find.text('关闭面板 / 退出全屏'), findsOneWidget);

    await tester.tap(find.byTooltip('关闭快捷键面板'));
    expect(closed, isTrue);
  });
}
