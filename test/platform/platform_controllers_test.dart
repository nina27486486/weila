import 'package:flutter_test/flutter_test.dart';
import 'package:weila/platform/app_window_controller.dart';
import 'package:weila/platform/fullscreen_controller.dart';

void main() {
  test('no-op fullscreen controller is safe for Android baseline', () async {
    const controller = NoopFullscreenController();
    await controller.setFullscreen(true);
    await controller.setFullscreen(false);
  });

  test('no-op window controller initializes without side effects', () async {
    const AppWindowController controller = NoopAppWindowController();
    await controller.initialize();
  });
}
