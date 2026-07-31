import 'package:flutter/widgets.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:media_kit/media_kit.dart';

import '../app_module.dart';
import '../app_widget.dart';
import '../platform/app_capabilities.dart';
import '../platform/app_window_controller.dart';
import '../platform/fullscreen_controller.dart';
import '../services/danmaku/dandanplay_credential_manager.dart';
import '../services/plugin/plugin_service.dart';
import '../services/storage/storage_service.dart';
import '../stores/theme_store.dart';

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

Future<void> launchWeila(AppLaunchConfiguration configuration) async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  await AppBootstrap(
    windowController: configuration.windowController,
    initializeStorage: StorageService().init,
    initializeCredentials: configuration.credentialManager.initialize,
    loadTheme: ThemeStore().loadTheme,
    initializePlugins: PluginService().init,
    initializeDownloads: configuration.capabilities.downloads
        ? configuration.initializeDownloads
        : null,
  ).initialize();

  runApp(
    ModularApp(
      module: AppModule(
        credentialManager: configuration.credentialManager,
        capabilities: configuration.capabilities,
        fullscreenController: configuration.fullscreenController,
      ),
      child: AppWidget(capabilities: configuration.capabilities),
    ),
  );
}
