import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../models/plugin.dart';
import '../../utils/constants.dart';
import '../../utils/logger.dart';

/// 插件列表的文件持久化。独立于业务逻辑，便于注入路径工厂做测试。
class PluginRepository {
  PluginRepository({Future<Directory> Function()? applicationSupportDirectory})
      : _applicationSupportDirectory =
            applicationSupportDirectory ?? getApplicationSupportDirectory;

  final Future<Directory> Function() _applicationSupportDirectory;

  Future<File> _pluginFile() async {
    final appDir = await _applicationSupportDirectory();
    final dir = Directory('${appDir.path}/${AppConstants.pluginsDir}');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return File('${dir.path}/${AppConstants.pluginsFile}');
  }

  /// 读取磁盘插件列表；无文件或损坏时返回空列表并记录日志。
  Future<List<Plugin>> load() async {
    final file = await _pluginFile();
    if (!await file.exists()) {
      Log.d('Plugin', '无插件文件，使用空列表');
      return [];
    }
    try {
      final json = jsonDecode(await file.readAsString()) as List;
      return json
          .map((e) => Plugin.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      Log.d('Plugin', '加载插件失败: $e');
      return [];
    }
  }

  Future<void> save(List<Plugin> plugins) async {
    final file = await _pluginFile();
    final json = plugins.map((p) => p.toJson()).toList();
    try {
      await file.writeAsString(const JsonEncoder.withIndent('  ').convert(json));
    } catch (e) {
      Log.e('Plugin', '保存插件列表失败', e);
    }
  }
}
