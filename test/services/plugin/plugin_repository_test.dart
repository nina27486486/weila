import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:weila/models/plugin.dart';
import 'package:weila/services/plugin/plugin_repository.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('weila_plugin_repo_test');
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  PluginRepository buildRepository() {
    return PluginRepository(
      applicationSupportDirectory: () async => tempDir,
    );
  }

  Plugin buildPlugin(String api) {
    return Plugin(
      api: api,
      name: '测试插件 $api',
      version: '1.0.0',
      baseUrl: 'https://example.com',
      searchURL: 'https://example.com/search?wd={keyword}',
      searchList: 'list',
      searchName: 'name',
      searchResult: 'url',
      chapterRoads: '',
      chapterResult: '',
      userAgent: 'test-agent',
      enabled: true,
    );
  }

  test('无插件文件时 load 返回空列表', () async {
    final repository = buildRepository();
    expect(await repository.load(), isEmpty);
  });

  test('save 后 load 能往返一致', () async {
    final repository = buildRepository();
    final plugins = [buildPlugin('a'), buildPlugin('b')];
    await repository.save(plugins);

    final loaded = await repository.load();
    expect(loaded, hasLength(2));
    expect(loaded.map((p) => p.api), ['a', 'b']);
    expect(loaded.first.name, '测试插件 a');
    expect(loaded.first.enabled, isTrue);
  });

  test('损坏的 JSON 文件 load 返回空列表而不抛异常', () async {
    final dir = Directory('${tempDir.path}/plugins/v2');
    await dir.create(recursive: true);
    await File('${dir.path}/plugins.json')
        .writeAsString('not a valid json list');

    final repository = buildRepository();
    expect(await repository.load(), isEmpty);
  });
}
