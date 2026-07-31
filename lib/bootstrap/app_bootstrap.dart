import '../platform/app_capabilities.dart';
import '../platform/app_window_controller.dart';
import '../platform/fullscreen_controller.dart';
import '../services/danmaku/dandanplay_credential_manager.dart';

typedef AsyncInitializer = Future<void> Function();
typedef SyncInitializer = void Function();

class AppLaunchConfiguration {
  AppLaunchConfiguration({
    required this.capabilities,
    required this.windowController,
    required this.fullscreenController,
    required this.credentialManager,
    this.initializeDownloads,
  }) : assert(!capabilities.downloads || initializeDownloads != null);

  final AppCapabilities capabilities;
  final AppWindowController windowController;
  final FullscreenController fullscreenController;
  final DanmakuCredentialManager credentialManager;
  final AsyncInitializer? initializeDownloads;
}

class AppBootstrap {
  const AppBootstrap({
    required this.windowController,
    required this.initializeStorage,
    required this.initializeCredentials,
    required this.loadTheme,
    required this.initializePlugins,
    this.initializeDownloads,
  });

  final AppWindowController windowController;
  final AsyncInitializer initializeStorage;
  final AsyncInitializer initializeCredentials;
  final SyncInitializer loadTheme;
  final AsyncInitializer initializePlugins;
  final AsyncInitializer? initializeDownloads;

  Future<void> initialize() async {
    await windowController.initialize();
    await initializeStorage();
    await initializeCredentials();
    loadTheme();
    await initializePlugins();
    await initializeDownloads?.call();
  }
}
