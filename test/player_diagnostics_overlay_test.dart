import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weila/pages/player/widgets/player_diagnostics_overlay.dart';

void main() {
  testWidgets('播放器诊断层展示故障信息并触发恢复操作', (tester) async {
    var retried = false;
    var switched = false;
    var backed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlayerDiagnosticsOverlay(
            issue: const PlayerDiagnosticIssue(
              icon: Icons.videocam_off_outlined,
              title: '未检测到视频画面',
              message: '音频已经开始播放，但解码器没有返回视频画面。',
            ),
            currentSourceIndex: 1,
            sourceCount: 3,
            position: const Duration(minutes: 12, seconds: 34),
            onRetry: () => retried = true,
            onSwitchSource: () => switched = true,
            onBack: () => backed = true,
          ),
        ),
      ),
    );

    expect(find.text('播放诊断'), findsOneWidget);
    expect(find.text('未检测到视频画面'), findsOneWidget);
    expect(find.text('音频已经开始播放，但解码器没有返回视频画面。'), findsOneWidget);
    expect(find.text('线路 2/3'), findsOneWidget);
    expect(find.text('进度 12:34'), findsOneWidget);

    await tester.tap(find.text('重新加载'));
    expect(retried, isTrue);

    await tester.tap(find.text('切换线路'));
    expect(switched, isTrue);

    await tester.tap(find.text('返回详情'));
    expect(backed, isTrue);
  });

  testWidgets('没有备用线路时不显示切换线路按钮', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlayerDiagnosticsOverlay(
            issue: const PlayerDiagnosticIssue(
              icon: Icons.link_off_rounded,
              title: '视频地址已经失效',
              message: '当前集数的播放地址不可用，请稍后再试。',
            ),
            onRetry: () {},
            onBack: () {},
          ),
        ),
      ),
    );

    expect(find.text('切换线路'), findsNothing);
    expect(find.text('重新加载'), findsOneWidget);
    expect(find.text('返回详情'), findsOneWidget);
  });

  testWidgets('播放器加载层展示当前连接状态', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PlayerLoadingOverlay(
            title: '正在重新连接',
            subtitle: '自动重试 1/1',
          ),
        ),
      ),
    );

    expect(find.text('正在重新连接'), findsOneWidget);
    expect(find.text('自动重试 1/1'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
