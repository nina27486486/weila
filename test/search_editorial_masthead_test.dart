import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weila/pages/search/search_editorial_masthead.dart';
import 'package:weila/theme/app_theme.dart';

void main() {
  testWidgets('搜索刊首呈现开放式输入区与关键词轨道', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = TextEditingController();
    final focusNode = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);
    String? keyword;
    var searched = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: SearchEditorialMasthead(
            controller: controller,
            focusNode: focusNode,
            focused: false,
            query: '',
            isLoading: false,
            enabledPluginCount: 2,
            history: const ['芙莉莲', '孤独摇滚'],
            suggestions: const [],
            onSearch: () => searched = true,
            onChanged: (_) {},
            onClearSearch: () {},
            onKeywordTap: (value) => keyword = value,
            onHistoryRemove: (_) {},
            onHistoryClear: () {},
          ),
        ),
      ),
    );

    expect(find.text('搜索动画'), findsOneWidget);
    expect(find.text('2 个片源已连接'), findsOneWidget);
    expect(
        find.byKey(const ValueKey('search-editorial-field')), findsOneWidget);
    expect(find.text('最近搜索'), findsOneWidget);

    await tester.tap(find.text('芙莉莲'));
    await tester.enterText(find.byType(TextField), '迷宫饭');
    await tester.tap(find.text('开始寻找'));
    expect(keyword, '芙莉莲');
    expect(searched, isTrue);
  });
}
