import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weila/pages/discover/broadcast_calendar_view.dart';
import 'package:weila/theme/app_theme.dart';

void main() {
  final weekData = List.generate(
    7,
    (day) => List.generate(
      day == 2 ? 4 : 1,
      (index) => <String, dynamic>{
        'name': '周${day + 1}作品${index + 1}',
        'cover': null,
        'status': '更新至第 ${index + 1} 集',
        'score': 8.4,
        'genres': ['奇幻', '日常'],
        'url': 'calendar:$day:$index',
      },
    ),
  );

  testWidgets('日历以周索引和当日节目单呈现放送信息', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var selectedDay = -1;
    Map<String, dynamic>? opened;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: BroadcastCalendarView(
            weekData: weekData,
            selectedDay: 2,
            todayIndex: 2,
            onDaySelected: (value) => selectedDay = value,
            onOpenAnime: (item) => opened = item,
            onRetry: () {},
            onRefresh: () {},
          ),
        ),
      ),
    );

    expect(find.text('追番日历'), findsOneWidget);
    expect(find.byKey(const ValueKey('calendar-week-strip')), findsOneWidget);
    expect(find.byKey(const ValueKey('calendar-day-grid')), findsOneWidget);
    expect(find.text('今天的放送'), findsOneWidget);
    expect(find.text('周三'), findsOneWidget);

    await tester.tap(find.text('周四'));
    await tester.tap(find.text('周3作品1'));
    expect(selectedDay, 3);
    expect(opened, weekData[2].first);
  });

  testWidgets('日历错误状态使用统一中文恢复动作', (tester) async {
    var retried = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: BroadcastCalendarView(
            weekData: List.generate(7, (_) => const []),
            selectedDay: 0,
            todayIndex: 0,
            errorMessage: '放送表加载失败',
            onDaySelected: (_) {},
            onOpenAnime: (_) {},
            onRetry: () => retried = true,
            onRefresh: () {},
          ),
        ),
      ),
    );

    expect(find.text('放送表暂时缺席'), findsOneWidget);
    await tester.tap(find.text('重新加载'));
    expect(retried, isTrue);
  });
}
