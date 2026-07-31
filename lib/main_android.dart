import 'bootstrap/app_bootstrap.dart';
import 'platform/app_capabilities.dart';
import 'platform/app_window_controller.dart';
import 'platform/fullscreen_controller.dart';
import 'services/danmaku/dandanplay_credential_manager.dart';
import 'services/danmaku/unavailable_danmaku_credential_store.dart';

Future<void> main() {
  return launchWeila(
    AppLaunchConfiguration(
      capabilities: AppCapabilities.androidCompileBaseline,
      windowController: const NoopAppWindowController(),
      fullscreenController: const NoopFullscreenController(),
      credentialManager: DanmakuCredentialManager.platform(
        store: const UnavailableDanmakuCredentialStore(),
      ),
    ),
  );
}
