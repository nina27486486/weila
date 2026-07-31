import 'package:flutter/widgets.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:media_kit/media_kit.dart';

import '../app_module.dart';
import '../app_widget.dart';
import '../services/plugin/plugin_service.dart';
import '../services/storage/storage_service.dart';
import '../stores/theme_store.dart';
import 'app_bootstrap.dart';

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
