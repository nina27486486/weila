import 'package:flutter/services.dart';

import 'fullscreen_controller.dart';

class AndroidFullscreenController implements FullscreenController {
  Future<void> _pending = Future<void>.value();
  Future<void>? _lastOperation;
  bool? _lastRequested;

  @override
  Future<void> setFullscreen(bool enabled) {
    if (_lastRequested == enabled && _lastOperation != null) {
      return _lastOperation!;
    }
    final operation = _pending.then((_) => _apply(enabled));
    _lastRequested = enabled;
    _lastOperation = operation;
    _pending = operation.then<void>((_) {
      if (identical(_lastOperation, operation)) _lastOperation = null;
    }, onError: (Object error, StackTrace stack) {
      if (identical(_lastOperation, operation)) _lastOperation = null;
    });
    return operation;
  }

  Future<void> _apply(bool enabled) async {
    if (enabled) {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      // API 36 可忽略沉浸请求，不以方法返回值判断系统栏是否隐藏。
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      try {
        // Android 入口未锁定方向，退出恢复系统默认而非强制竖屏。
        await SystemChrome.setPreferredOrientations([]);
      } finally {
        await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      }
    }
  }
}
