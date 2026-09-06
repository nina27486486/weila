import 'package:flutter_test/flutter_test.dart';
import 'package:weila/models/plugin.dart';
import 'package:weila/services/plugin/plugin_defaults.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PluginDefaults.cmsCategories', () {
    test('覆盖两个内置 CMS 源', () {
      expect(PluginDefaults.cmsCategories.keys, containsAll(['cms_yinhua', 'cms_ffzy']));
    });

    test('每个分类条目包含正整数 id 与名称', () {
      for (final entry in PluginDefaults.cmsCategories.entries) {
        for (final category in entry.value) {
          expect(category['id'], isA<int>());
          expect(category['name']?.toString(), isNotEmpty);
        }
      }
    });
  });

  group('PluginDefaults.createDefaultPlugins', () {
    test('包含元数据源、模板与两个 CMS 源', () {
      final apis = PluginDefaults.createDefaultPlugins().map((p) => p.api).toList();
      expect(apis, containsAll([
        'jikan',
        'anilist',
        'bangumi',
        'maccms_template',
        'cms_ffzy',
        'cms_yinhua',
      ]));
    });

    test('CMS 默认源带内建目录配置', () {
      final cmsPlugins = PluginDefaults
          .createDefaultPlugins()
          .where((p) => p.api.startsWith('cms_'));
      for (final plugin in cmsPlugins) {
        expect(plugin.catalog, isNotNull, reason: '${plugin.api} 应有 catalog 配置');
      }
    });
  });

  group('PluginDefaults.mergeInto', () {
    test('空列表合并出全部默认插件且标记变更', () {
      final result = PluginDefaults.mergeInto([]);
      expect(result.changed, isTrue);
      expect(result.plugins.length,
          PluginDefaults.createDefaultPlugins().length);
    });

    test('已存在的默认插件不重复添加', () {
      final existing = PluginDefaults.createDefaultPlugins();
      final result = PluginDefaults.mergeInto(existing);
      expect(result.changed, isFalse);
      expect(result.plugins.length, existing.length);
    });

    test('按 api 去重：保留用户已有的同名插件', () {
      final custom = Plugin(
        api: 'cms_yinhua',
        name: '自定义樱花镜像',
        version: '2.0.0',
        baseUrl: 'https://mirror.example.com',
        searchURL: 'https://mirror.example.com/search?wd={keyword}',
        searchList: 'list',
        searchName: 'vod_name',
        searchResult: 'vod_id',
        chapterRoads: '',
        chapterResult: '',
        userAgent: 'test-agent',
        enabled: true,
      );
      final result = PluginDefaults.mergeInto([custom]);
      expect(result.changed, isTrue); // 仍会补充其他默认插件
      final yinhua =
          result.plugins.where((p) => p.api == 'cms_yinhua').toList();
      expect(yinhua, hasLength(1));
      expect(yinhua.single.name, '自定义樱花镜像');
      expect(yinhua.single.baseUrl, 'https://mirror.example.com');
    });
  });
}
