import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weila/pages/download/offline_library_view.dart';
import 'package:weila/theme/app_theme.dart';

void main() {
  final episodes = [
    const OfflineEpisode(
      id: '1',
      animeName: '离线作品',
      episodeName: '第 1 集',
      status: OfflineStatus.downloading,
      progress: 0.48,
      fileSizeLabel: '128.0 MB',
      segmentLabel: '24 / 50',
    ),
    const OfflineEpisode(
      id: '2',
      animeName: '离线作品',
      episodeName: '第 2 集',
      status: OfflineStatus.completed,
      progress: 1,
      fileSizeLabel: '256.0 MB',
    ),
  ];

  testWidgets('离线片库展示总览、作品分组与任务操作', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    OfflineEpisode? paused;
    OfflineEpisode? played;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: OfflineLibraryView(
            episodes: episodes,
            onPause: (entry) => paused = entry,
            onResume: (_) {},
            onRetry: (_) {},
            onPlay: (entry) => played = entry,
            onRemove: (_) {},
            onRefresh: () {},
          ),
        ),
      ),
    );

    expect(find.text('离线放映室'), findsOneWidget);
    expect(find.byKey(const ValueKey('offline-overview')), findsOneWidget);
    expect(find.byKey(const ValueKey('offline-task-list')), findsOneWidget);
    expect(find.text('正在下载'), findsOneWidget);
    expect(find.text('已完成'), findsWidgets);

    await tester.tap(find.byTooltip('暂停下载'));
    await tester.tap(find.byTooltip('播放缓存'));
    expect(paused, episodes.first);
    expect(played, episodes.last);
  });
}
