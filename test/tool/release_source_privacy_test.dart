import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('playback surfaces do not interpolate raw media errors', () {
    final playerSource =
        File('lib/pages/player/player_page.dart').readAsStringSync();
    final detailSource = File('lib/pages/detail/widgets/detail_page_view.dart')
        .readAsStringSync();

    expect(playerSource, isNot(contains(r'连接视频源超时: $url')));
    expect(playerSource, isNot(contains(r'播放失败: $url')));
    expect(playerSource, isNot(contains(r'media_kit: $message')));
    expect(playerSource, isNot(contains(r'加载集数失败: $e')));
    expect(playerSource, isNot(contains(r'获取视频源失败: $e')));
    expect(detailSource, isNot(contains(r'CMS 播放失败: $e')));
    expect(detailSource, isNot(contains(r'播放失败: $e')));
  });
}
