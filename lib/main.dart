import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:media_kit/media_kit.dart';
import 'package:window_manager/window_manager.dart';

import 'app_module.dart';
import 'app_widget.dart';
import 'services/storage/storage_service.dart';
import 'services/plugin/plugin_service.dart';
import 'services/download/download_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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

  // 初始化 Hive 本地存储
  await StorageService().init();

  // 初始化插件系统
  await PluginService().init();

  // 初始化下载服务
  await DownloadService().init();

  // 启动应用
  runApp(ModularApp(module: AppModule(), child: const AppWidget()));
}
