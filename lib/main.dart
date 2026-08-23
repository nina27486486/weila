import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:media_kit/media_kit.dart';
import 'package:window_manager/window_manager.dart';

import 'app_module.dart';
import 'app_widget.dart';
import 'services/danmaku/dandanplay_credential_manager.dart';
import 'services/storage/storage_service.dart';
import 'services/http/http_client.dart';
import 'services/plugin/plugin_service.dart';
import 'services/download/download_service.dart';
import 'stores/theme_store.dart';
import 'utils/logger.dart';

void main() {
  runZonedGuarded(_bootstrap, (error, stackTrace) {
    Log.e('App', '未捕获异步异常', error);
  });
}

Future<void> _bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

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

  // 初始化 media_kit
  MediaKit.ensureInitialized();

  // 初始化窗口管理
  await windowManager.ensureInitialized();
  const windowOptions = WindowOptions(
    size: Size(1280, 800),
    minimumSize: Size(960, 640),
    center: true,
    title: '薇拉',
  );
  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  // 存储是收藏/历史/设置/目录缓存的地基，失败时进入降级错误页，
  // 不能让后续依赖存储的初始化在白屏里静默死掉。
  try {
    await StorageService().init();
  } catch (error) {
    Log.e('Startup', '本地存储初始化失败', error);
    runApp(_StartupFailureApp(reason: error));
    return;
  }

  // 主网络栈与下载栈共用同一份代理设置（存储初始化成功后才可读）。
  _guardSync('网络代理', () {
    HttpClient().setProxy(StorageService().getDownloadSettings().proxyRuleFor);
  });

  // 各功能服务独立降级：单个服务失败只损失对应能力，不阻断应用启动。
  await _guard('弹幕凭据', DanmakuCredentialManager().initialize);
  _guardSync('主题加载', ThemeStore().loadTheme);
  await _guard('插件系统', PluginService().init);
  await _guard('下载服务', DownloadService().init);

  // 启动应用
  runApp(ModularApp(module: AppModule(), child: const AppWidget()));
}

Future<void> _guard(String name, Future<void> Function() step) async {
  try {
    await step();
  } catch (error) {
    Log.e('Startup', '$name初始化失败，对应功能将降级', error);
  }
}

void _guardSync(String name, void Function() step) {
  try {
    step();
  } catch (error) {
    Log.e('Startup', '$name初始化失败，对应功能将降级', error);
  }
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
