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
    expect(
      find.byKey(const ValueKey('archive-featured-stage')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('archive-poster-grid')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('library-ambient-backdrop')),
      findsOneWidget,
    );
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
    expect(
      find.byKey(const ValueKey('archive-progress-stack-0')),
      findsOneWidget,
    );
    expect(find.text('连载中'), findsWidgets);
    expect(find.text('看到这里'), findsWidgets);
  });

  testWidgets('海报模式少于三项时只显示精选舞台且保持可操作', (tester) async {
    ArchiveEntry? opened;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: PersonalArchiveView(
            title: '少量收藏',
            description: '两部也能组成自己的小书架。',
            mode: ArchiveDisplayMode.poster,
            entries: entries.take(2).toList(),
            onOpen: (entry) => opened = entry,
            onRemove: (_) {},
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('archive-featured-stage')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('archive-poster-grid')), findsNothing);
    await tester.tap(find.text(entries.first.title));
    expect(opened, entries.first);
    expect(tester.takeException(), isNull);
  });

  testWidgets('历史模式显示墨迹时间线标记', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: PersonalArchiveView(
            title: '观看足迹',
            description: '沿着时间继续。',
            mode: ArchiveDisplayMode.timeline,
            entries: entries,
            onOpen: (_) {},
            onRemove: (_) {},
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('archive-ink-timeline-0')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('收藏页在 960、1280、1600 宽度下保持精选舞台完整', (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));

    for (final width in [960.0, 1280.0, 1600.0]) {
      await tester.binding.setSurfaceSize(Size(width, 900));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: PersonalArchiveView(
              title: '响应式资料库',
              description: '不同桌面宽度下都保持清楚。',
              mode: ArchiveDisplayMode.poster,
              entries: entries,
              onOpen: (_) {},
              onRemove: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(
        find.byKey(const ValueKey('archive-featured-stage')),
        findsOneWidget,
      );
    }
  });
}
