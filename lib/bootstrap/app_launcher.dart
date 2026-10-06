import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:media_kit/media_kit.dart';

import '../app_module.dart';
import '../app_widget.dart';
import '../services/http/http_client.dart';
import '../services/plugin/plugin_service.dart';
import '../services/storage/storage_service.dart';
import '../stores/theme_store.dart';
import '../utils/logger.dart';
import 'app_bootstrap.dart';

Future<void> launchWeila(AppLaunchConfiguration configuration) async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  try {
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
  } catch (error) {
    // 存储初始化失败：进入降级错误页，不启动主应用。
    Log.e('Startup', '本地存储初始化失败', error);
    runApp(_StartupFailureApp(reason: error));
    return;
  }

  // 主网络栈与下载栈共用同一份代理设置（存储初始化成功后才可读）。
  try {
    HttpClient()
        .setProxy(StorageService().getDownloadSettings().proxyRuleFor);
  } catch (error) {
    Log.e('Startup', '网络代理初始化失败，保持直连', error);
  }

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

/// 存储不可用时的启动失败页：说明原因并提示处理方式，
/// 不依赖 Hive、路由和主题，保证任何情况下都能渲染。
class _StartupFailureApp extends StatelessWidget {
  const _StartupFailureApp({this.reason});

  final Object? reason;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '薇拉',
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF0E1216),
        body: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 520),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: const Color(0xFF161B21),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF2A323B)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.folder_off_outlined,
                  color: Color(0xFF8A93A0),
                  size: 40,
                ),
                const SizedBox(height: 16),
                const Text(
                  '本地数据无法打开',
                  style: TextStyle(
                    color: Color(0xFFE8ECF1),
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '薇拉的收藏、历史与设置存储可能已损坏。\n'
                  '可以关闭应用后重试；若持续出现，请删除应用数据目录后重新启动，'
                  '或重新安装应用。',
                  style: TextStyle(
                    color: Color(0xFF9AA4B0),
                    fontSize: 14,
                    height: 1.6,
                  ),
                ),
                if (kDebugMode && reason != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    '调试信息：$reason',
                    style: const TextStyle(
                      color: Color(0xFF6C7683),
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
