import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weila/utils/error_handler.dart';

Widget _host() {
  return MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                onPressed: () => ErrorHandler.showError(context, '播放失败'),
                child: const Text('error'),
              ),
              TextButton(
                onPressed: () => ErrorHandler.showSuccess(context, '已保存'),
                child: const Text('success'),
              ),
              TextButton(
                onPressed: () => ErrorHandler.showInfo(context, '未找到集数信息'),
                child: const Text('info'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

void main() {
  Future<void> tapAndSettle(WidgetTester tester, String label) async {
    await tester.tap(find.text(label));
    await tester.pump();
    // SnackBar 有入场动画，用固定时长推进而不是 pumpAndSettle。
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('showError 展示错误文案', (tester) async {
    await tester.pumpWidget(_host());
    await tapAndSettle(tester, 'error');
    expect(find.text('播放失败'), findsOneWidget);
    expect(find.textContaining('重试'), findsNothing);
  });

  testWidgets('showError 支持重试回调', (tester) async {
    var retries = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () => ErrorHandler.showError(
                  context,
                  '线路不可用',
                  onRetry: () => retries++,
                ),
                child: const Text('error-retry'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('error-retry'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('线路不可用'), findsOneWidget);
    await tester.tap(find.text('重试'));
    expect(retries, 1);
  });

  testWidgets('showSuccess 展示成功文案', (tester) async {
    await tester.pumpWidget(_host());
    await tapAndSettle(tester, 'success');
    expect(find.text('已保存'), findsOneWidget);
  });

  testWidgets('showInfo 展示信息文案', (tester) async {
    await tester.pumpWidget(_host());
    await tapAndSettle(tester, 'info');
    expect(find.text('未找到集数信息'), findsOneWidget);
  });
}
