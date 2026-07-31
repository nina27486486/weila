import 'bootstrap/app_bootstrap.dart';
import 'bootstrap/app_launcher.dart';
import 'platform/app_capabilities.dart';
import 'platform/windows/window_manager_app_window_controller.dart';
import 'platform/windows/window_manager_fullscreen_controller.dart';
import 'services/danmaku/dandanplay_credential_manager.dart';
import 'services/danmaku/windows_danmaku_credential_store.dart';
import 'services/download/download_service.dart';

Future<void> main() {
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
}
