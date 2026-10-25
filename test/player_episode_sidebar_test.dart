import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weila/models/anime.dart';
import 'package:weila/pages/player/widgets/episode_sidebar.dart';
import 'package:weila/theme/app_theme.dart';

void main() {
  testWidgets('Android抽屉关闭动画每一帧均保持非负宽度', (tester) async {
    Widget build(bool open) => MaterialApp(
          theme: AppTheme.darkTheme.copyWith(platform: TargetPlatform.android),
          home: Scaffold(
            body: Align(
              alignment: Alignment.centerRight,
              child: EpisodeDrawerMotion(
                open: open,
                child: const ColoredBox(color: Colors.black),
              ),
            ),
          ),
        );
    await tester.pumpWidget(build(true));
    await tester.pumpWidget(build(false));
    for (var frame = 0; frame < 16; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.takeException(), isNull);
      expect(
          tester
              .getSize(find.byKey(
                const ValueKey('episode-drawer-motion'),
              ))
              .width,
          greaterThanOrEqualTo(0));
    }
  });

  testWidgets('选集抽屉提供明确的关闭操作', (tester) async {
    var closed = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: SizedBox(
            width: 220,
            child: EpisodeSidebar(
              episodes: [
                Episode(name: '第 1 集', url: 'episode-1', index: 0),
                Episode(name: '第 2 集', url: 'episode-2', index: 1),
              ],
              currentIndex: 0,
              onEpisodeTap: (_) {},
              onClose: () => closed = true,
            ),
          ),
        ),
      ),
    );

    expect(find.byTooltip('关闭选集'), findsOneWidget);
    await tester.tap(find.byTooltip('关闭选集'));
    expect(closed, isTrue);
  });

  testWidgets('Windows选集抽屉保留 240ms 弹性过渡', (tester) async {
    Widget build(bool open) {
      return MaterialApp(
        theme: AppTheme.darkTheme.copyWith(platform: TargetPlatform.windows),
        home: Scaffold(
          body: Align(
            alignment: Alignment.centerRight,
            child: EpisodeDrawerMotion(
              open: open,
              child: const ColoredBox(color: Colors.black),
            ),
          ),
        ),
      );
    }

    await tester.pumpWidget(build(false));
    var motion = tester.widget<AnimatedContainer>(
      find.byKey(const ValueKey('episode-drawer-motion')),
    );
    expect(motion.constraints?.maxWidth, 0);
    expect(motion.duration, const Duration(milliseconds: 240));
    expect(motion.curve, Curves.easeOutBack);

    await tester.pumpWidget(build(true));
    await tester.pump(const Duration(milliseconds: 240));
    motion = tester.widget<AnimatedContainer>(
      find.byKey(const ValueKey('episode-drawer-motion')),
    );
    expect(motion.constraints?.maxWidth, 220);
    expect(tester.takeException(), isNull);
  });
}
