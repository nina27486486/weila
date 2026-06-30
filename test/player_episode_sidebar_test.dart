import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weila/models/anime.dart';
import 'package:weila/pages/player/widgets/episode_sidebar.dart';
import 'package:weila/theme/app_theme.dart';

void main() {
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
}
