import 'dart:async';

import 'package:flutter/foundation.dart';

import 'bootstrap/app_bootstrap.dart';
import 'bootstrap/app_launcher.dart';
import 'platform/app_capabilities.dart';
import 'platform/windows/window_manager_app_window_controller.dart';
import 'platform/windows/window_manager_fullscreen_controller.dart';
import 'services/danmaku/dandanplay_credential_manager.dart';
import 'services/danmaku/windows_danmaku_credential_store.dart';
import 'services/download/download_service.dart';
import 'utils/logger.dart';

void main() {
  runZonedGuarded(() {
    // 框架渲染期错误：保留默认输出并统一记录。
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      Log.e('Flutter', details.exceptionAsString(), details.exception);
    };
    // 异步/平台派发错误：标记已处理，避免 Release 下直接崩溃闪退。
    PlatformDispatcher.instance.onError = (error, stackTrace) {
      Log.e('Platform', '未捕获平台异常', error);
      return true;
    };
    return launchWeila(
      AppLaunchConfiguration(
        capabilities: AppCapabilities.windows,
        windowController: const WindowManagerAppWindowController(),
        fullscreenController: const WindowManagerFullscreenController(),
        credentialManager: DanmakuCredentialManager.platform(
          store: WindowsDanmakuCredentialStore(),
        ),
        initializeDownloads: DownloadService().init,
      ),
    );
  }, (error, stackTrace) {
    Log.e('App', '未捕获异步异常', error);
  });
}
