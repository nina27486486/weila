import 'package:flutter_test/flutter_test.dart';
import 'package:weila/pages/player/player_episode_selection.dart';

void main() {
  test('initial route episode is also the initial danmaku episode', () {
    final selection = PlayerEpisodeSelection(initialIndex: 11);

    expect(selection.index, 11);
    expect(selection.danmakuEpisodeNumber, 12);
  });

  test('selecting another episode updates its danmaku episode number', () {
    final selection = PlayerEpisodeSelection(initialIndex: 0);

    selection.select(2);

    expect(selection.index, 2);
    expect(selection.danmakuEpisodeNumber, 3);
  });
}
