import 'package:window_manager/window_manager.dart';

import '../fullscreen_controller.dart';

class WindowManagerFullscreenController implements FullscreenController {
  const WindowManagerFullscreenController();

  @override
  Future<void> setFullscreen(bool enabled) =>
      windowManager.setFullScreen(enabled);
}
