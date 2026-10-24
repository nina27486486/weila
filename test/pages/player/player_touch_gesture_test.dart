import 'package:flutter_test/flutter_test.dart';
import 'package:weila/pages/player/player_touch_gesture.dart';

void main() {
  group('resolveDoubleTapZone', () {
    test('三等分：左/中/右各归其区', () {
      const width = 411.0;
      expect(
        resolveDoubleTapZone(localX: width / 6, width: width),
        PlayerDoubleTapZone.back,
      );
      expect(
        resolveDoubleTapZone(localX: width / 2, width: width),
        PlayerDoubleTapZone.center,
      );
      expect(
        resolveDoubleTapZone(localX: width * 5 / 6, width: width),
        PlayerDoubleTapZone.forward,
      );
    });

    test('360dp 窄屏同样适用', () {
      const width = 360.0;
      expect(
        resolveDoubleTapZone(localX: 30, width: width),
        PlayerDoubleTapZone.back,
      );
      expect(
        resolveDoubleTapZone(localX: 180, width: width),
        PlayerDoubleTapZone.center,
      );
      expect(
        resolveDoubleTapZone(localX: 340, width: width),
        PlayerDoubleTapZone.forward,
      );
    });

    test('越界坐标被收敛到最近区域', () {
      const width = 360.0;
      expect(
        resolveDoubleTapZone(localX: -50, width: width),
        PlayerDoubleTapZone.back,
      );
      expect(
        resolveDoubleTapZone(localX: width + 50, width: width),
        PlayerDoubleTapZone.forward,
      );
    });

    test('横屏宽幅下仍为三等分', () {
      const width = 780.0;
      expect(
        resolveDoubleTapZone(localX: 100, width: width),
        PlayerDoubleTapZone.back,
      );
      expect(
        resolveDoubleTapZone(localX: width - 100, width: width),
        PlayerDoubleTapZone.forward,
      );
    });

    test('双击快进常量为 10 秒', () {
      expect(playerDoubleTapSeekOffset, const Duration(seconds: 10));
    });
  });
}
