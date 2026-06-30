import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weila/pages/library/personal_archive_view.dart';
import 'package:weila/theme/app_theme.dart';

void main() {
  final entries = List.generate(
    4,
    (index) => ArchiveEntry(
      id: 'entry:$index',
      title: '资料库作品 ${index + 1}',
      coverUrl: null,
      subtitle: '第 ${index + 3} 集',
      meta: '昨天继续观看',
      sourceLabel: '樱花动漫',
      progress: 0.58,
      statusLabel: index.isEven ? '连载中' : '已完结',
    ),
  );

  testWidgets('收藏页使用封面档案墙和资料库分栏', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    ArchiveEntry? opened;
    String? section;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: PersonalArchiveView(
            title: '我的资料库',
            description: '把值得回看的作品收进自己的动画书架。',
            mode: ArchiveDisplayMode.poster,
            entries: entries,
            sections: const [
              ArchiveSection(id: 'collect', label: '收藏夹'),
              ArchiveSection(id: 'history', label: '观看足迹'),
            ],
            selectedSectionId: 'collect',
            onSectionSelected: (value) => section = value,
            onOpen: (entry) => opened = entry,
            onRemove: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('我的资料库'), findsOneWidget);
    expect(find.byKey(const ValueKey('archive-poster-grid')), findsOneWidget);
    expect(find.text('收藏夹'), findsOneWidget);

    await tester.tap(find.text('观看足迹'));
    await tester.tap(find.text('资料库作品 1'));
    expect(section, 'history');
    expect(opened, entries.first);
  });

  testWidgets('追番页使用观看进度手账', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1100, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: PersonalArchiveView(
            title: '追番手账',
            description: '正在发生的故事，都在这里。',
            mode: ArchiveDisplayMode.progress,
            entries: entries,
            onOpen: (_) {},
            onRemove: (_) {},
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('archive-progress-list')), findsOneWidget);
    expect(find.text('连载中'), findsWidgets);
    expect(find.text('看到这里'), findsWidgets);
  });
}
