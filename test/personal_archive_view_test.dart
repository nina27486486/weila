import 'package:flutter/gestures.dart';
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
    for (final entry in entries) {
      expect(
        find.byKey(ValueKey('artwork-card-archive-${entry.id}')),
        findsOneWidget,
      );
      expect(
        find.byKey(ValueKey('artwork-card-action-archive-${entry.id}')),
        findsOneWidget,
      );
      expect(
        find.byKey(ValueKey('archive-rank-${entry.id}')),
        findsOneWidget,
      );
    }

    await tester.tap(find.text('观看足迹'));
    await tester.tap(
      find.byKey(
        ValueKey('artwork-card-action-archive-${entries.first.id}'),
      ),
    );
    expect(section, 'history');
    expect(opened, entries.first);
  });

  testWidgets('收藏卡封面局部裁切且删除操作不会打开作品', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    ArchiveEntry? opened;
    ArchiveEntry? removed;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: PersonalArchiveView(
            title: '我的资料库',
            description: '保存值得重看的作品。',
            mode: ArchiveDisplayMode.poster,
            entries: entries,
            onOpen: (entry) => opened = entry,
            onRemove: (entry) => removed = entry,
          ),
        ),
      ),
    );

    final first = entries.first;
    final clip = find.byKey(ValueKey('archive-cover-clip-${first.id}'));
    final cover = find.byKey(ValueKey('archive-cover-scale-${first.id}'));
    expect(clip, findsOneWidget);
    expect(tester.widget<ClipRect>(clip).clipBehavior, Clip.hardEdge);
    expect(find.descendant(of: clip, matching: cover), findsOneWidget);

    await tester.tap(find.byTooltip('移除${first.title}'));
    expect(removed, first);
    expect(opened, isNull);

    await tester.tap(
      find.byKey(ValueKey('artwork-card-action-archive-${first.id}')),
    );
    expect(opened, first);
  });

  testWidgets('收藏卡语义使用可读序号和番名而不朗读内部地址', (tester) async {
    final semantics = tester.ensureSemantics();
    const animeUrl = 'https://anime.example/detail/season-1';
    const title = '天空日记';

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: PersonalArchiveView(
            title: '我的资料库',
            description: '保存值得重看的作品。',
            mode: ArchiveDisplayMode.poster,
            entries: const [
              ArchiveEntry(
                id: animeUrl,
                title: title,
                coverUrl: null,
                subtitle: '第 1 集',
                meta: '刚刚收藏',
              ),
            ],
            onOpen: (_) {},
            onRemove: (_) {},
          ),
        ),
      ),
    );

    expect(find.bySemanticsLabel(RegExp('anime\\.example')), findsNothing);
    expect(find.bySemanticsLabel('打开第1项收藏，$title'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('收藏卡悬停时轻推封面并在离开后复位', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: PersonalArchiveView(
            title: '我的资料库',
            description: '保存值得重看的作品。',
            mode: ArchiveDisplayMode.poster,
            entries: entries,
            onOpen: (_) {},
            onRemove: (_) {},
          ),
        ),
      ),
    );

    final first = entries.first;
    final card = find.byKey(ValueKey('artwork-card-archive-${first.id}'));
    final cover = find.byKey(ValueKey('archive-cover-scale-${first.id}'));
    expect(tester.widget<AnimatedScale>(cover).scale, 1);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(card));
    await tester.pump();
    expect(tester.widget<AnimatedScale>(cover).scale, 1.025);

    await mouse.moveTo(const Offset(1200, 20));
    await tester.pump();
    expect(tester.widget<AnimatedScale>(cover).scale, 1);
  });

  testWidgets('收藏卡在减少动态效果时不缩放封面或抬升卡片', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: PersonalArchiveView(
              title: '我的资料库',
              description: '保存值得重看的作品。',
              mode: ArchiveDisplayMode.poster,
              entries: entries,
              onOpen: (_) {},
              onRemove: (_) {},
            ),
          ),
        ),
      ),
    );

    final first = entries.first;
    final card = find.byKey(ValueKey('artwork-card-archive-${first.id}'));
    final cover = find.byKey(ValueKey('archive-cover-scale-${first.id}'));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(card));
    await tester.pump();

    final surface = tester.widget<AnimatedContainer>(card);
    expect(surface.duration, Duration.zero);
    expect(surface.transform?.getTranslation().y, 0);
    expect(tester.widget<AnimatedScale>(cover).scale, 1);
  });

  testWidgets('收藏卡保留超长标题的单行省略规则', (tester) async {
    final longTitle = '这是一部标题特别特别长但仍然要维持卡片排版完整的动画作品';
    final longEntry = ArchiveEntry(
      id: 'long',
      title: longTitle,
      coverUrl: null,
      subtitle: '第 1 集',
      meta: '刚刚收藏',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: PersonalArchiveView(
            title: '我的资料库',
            description: '保存值得重看的作品。',
            mode: ArchiveDisplayMode.poster,
            entries: [longEntry],
            onOpen: (_) {},
            onRemove: (_) {},
          ),
        ),
      ),
    );

    final title = tester.widget<Text>(find.text(longTitle));
    expect(title.maxLines, 1);
    expect(title.overflow, TextOverflow.ellipsis);
    expect(tester.takeException(), isNull);
  });

  testWidgets('收藏项目更新后按原有顺序补齐精选舞台', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    Widget buildArchive(List<ArchiveEntry> visibleEntries) {
      return MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: PersonalArchiveView(
            title: '我的资料库',
            description: '保存值得重看的作品。',
            mode: ArchiveDisplayMode.poster,
            entries: visibleEntries,
            onOpen: (_) {},
            onRemove: (_) {},
          ),
        ),
      );
    }

    await tester.pumpWidget(buildArchive(entries));
    expect(
      find.byKey(ValueKey('artwork-card-archive-${entries[3].id}')),
      findsOneWidget,
    );

    final afterRemoval = entries.skip(1).toList(growable: false);
    await tester.pumpWidget(buildArchive(afterRemoval));
    await tester.pump();

    for (final entry in afterRemoval) {
      expect(
        find.byKey(ValueKey('artwork-card-archive-${entry.id}')),
        findsOneWidget,
      );
    }
    expect(
      find.byKey(ValueKey('artwork-card-archive-${entries.first.id}')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('archive-poster-grid')), findsNothing);
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
    await tester.tap(
      find.byKey(
        ValueKey('artwork-card-action-archive-${entries.first.id}'),
      ),
    );
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
