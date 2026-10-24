import '../platform/app_capabilities.dart';
import '../platform/app_window_controller.dart';
import '../platform/fullscreen_controller.dart';
import '../services/danmaku/dandanplay_credential_manager.dart';
import '../utils/logger.dart';

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
    // 存储是收藏/历史/设置/目录缓存的地基，失败时向上抛给 launcher
    // 进入降级错误页，而不是继续在无存储状态启动。
    await initializeStorage();
    // 其余各步独立降级：单个服务失败只损失对应能力，不阻断启动。
    await _guard('弹幕凭据', initializeCredentials);
    _guardSync('主题加载', loadTheme);
    await _guard('插件系统', initializePlugins);
    await _guard('下载服务', initializeDownloads);
  }

  Future<void> _guard(String name, AsyncInitializer? step) async {
    if (step == null) return;
    try {
      await step();
    } catch (error) {
      Log.e('Bootstrap', '$name初始化失败，对应功能将降级', error);
    }
  }

  void _guardSync(String name, SyncInitializer? step) {
    if (step == null) return;
    try {
      step();
    } catch (error) {
      Log.e('Bootstrap', '$name初始化失败，对应功能将降级', error);
    }
  }
}
