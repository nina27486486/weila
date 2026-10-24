import 'package:flutter_test/flutter_test.dart';
import 'package:weila/pages/player/player_layout_metrics.dart';

void main() {
  test('宽屏保持 360 桌面规格', () {
    expect(playerTopToolbarWidthFor(1280), 360);
    expect(playerTopToolbarWidthFor(960), 360);
    expect(playerTopToolbarWidthFor(720), 360);
  });

  test('360dp 手机屏收缩到一半左右', () {
    final width = playerTopToolbarWidthFor(360);
    expect(width, closeTo(198, 0.1));
    expect(width, lessThan(360));
  });

  test('极端窄屏不低于 160 下限', () {
    expect(playerTopToolbarWidthFor(240), 160);
  });
}
