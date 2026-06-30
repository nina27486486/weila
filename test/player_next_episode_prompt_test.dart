import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weila/pages/player/widgets/player_next_episode_prompt.dart';

void main() {
  testWidgets('下一集提示展示集数并触发播放和关闭', (tester) async {
    var played = false;
    var dismissed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: PlayerNextEpisodePrompt(
              episodeName: '第 12 集 星海的约定',
              onPlay: () => played = true,
              onDismiss: () => dismissed = true,
            ),
          ),
        ),
      ),
    );

    expect(find.text('即将播放'), findsOneWidget);
    expect(find.text('第 12 集 星海的约定'), findsOneWidget);
    expect(find.text('立即播放'), findsOneWidget);

    await tester.tap(find.text('立即播放'));
    expect(played, isTrue);

    await tester.tap(find.byTooltip('关闭下一集提示'));
    expect(dismissed, isTrue);
  });
}
