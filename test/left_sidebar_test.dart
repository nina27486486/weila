import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weila/theme/app_theme.dart';
import 'package:weila/widgets/left_sidebar.dart';

void main() {
  testWidgets('主导航不展示尚未实现的页面入口', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: LeftSidebar(
            selectedIndex: 0,
            onIndexChanged: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('稍后再看'), findsNothing);
    expect(find.text('个人中心'), findsNothing);
    expect(find.text('离线缓存'), findsOneWidget);
    expect(find.text('收藏夹'), findsOneWidget);
  });
}
