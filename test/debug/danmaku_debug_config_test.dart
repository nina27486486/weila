import 'package:flutter_test/flutter_test.dart';
import 'package:weila/debug/danmaku_debug_config.dart';

void main() {
  test('debug mode is enabled outside release builds', () {
    expect(
      resolveDanmakuDebugMode(releaseMode: false, requestedByDefine: false),
      isTrue,
    );
  });

  test('normal release hides debug mode unless explicitly requested', () {
    expect(
      resolveDanmakuDebugMode(releaseMode: true, requestedByDefine: false),
      isFalse,
    );
    expect(
      resolveDanmakuDebugMode(releaseMode: true, requestedByDefine: true),
      isTrue,
    );
  });
}
