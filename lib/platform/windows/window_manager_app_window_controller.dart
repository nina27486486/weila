import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../app_window_controller.dart';

class WindowManagerAppWindowController implements AppWindowController {
  const WindowManagerAppWindowController();

  @override
  Future<void> initialize() async {
    await windowManager.ensureInitialized();
    const options = WindowOptions(
      size: Size(1280, 800),
      minimumSize: Size(960, 640),
      center: true,
      title: '薇拉',
    );
    await windowManager.waitUntilReadyToShow(options, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }
}
