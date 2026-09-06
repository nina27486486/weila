import '../../models/plugin.dart';
import '../../models/plugin_catalog.dart';
import '../../utils/constants.dart';

/// 内置插件注册表：默认插件定义、CMS 分类表与默认合并规则。
class PluginDefaults {
  PluginDefaults._();

  /// CMS 分类定义（樱花动漫 / 非凡资源）
  static const Map<String, List<Map<String, dynamic>>> cmsCategories = {
    'cms_yinhua': [
      {'id': 10, 'name': '日本动漫'},
      {'id': 9, 'name': '国产动漫'},
      {'id': 11, 'name': '欧美动漫'},
      {'id': 12, 'name': '港台动漫'},
    ],
    'cms_ffzy': [
      {'id': 30, 'name': '日韩动漫'},
      {'id': 29, 'name': '国产动漫'},
      {'id': 31, 'name': '欧美动漫'},
    ],
  };

  /// 创建默认插件列表。
  static List<Plugin> createDefaultPlugins() {
    return [
      // Jikan API (MyAnimeList) - 高质量元数据、排行榜、季度新番
      Plugin(
        api: 'jikan',
        name: 'Jikan (MAL)',
        version: '1.0.0',
        baseUrl: 'https://api.jikan.moe',
        searchURL: 'https://api.jikan.moe/v4/anime?q={keyword}',
        searchList: 'data',
        searchName: 'title',
        searchResult: 'mal_id',
        chapterRoads: '',
        chapterResult: '',
        userAgent: AppConstants.defaultUserAgent,
        enabled: true,
      ),
      // Anilist GraphQL API - 搜索动漫元数据（国际源，稳定可用）
      Plugin(
        api: 'anilist',
        name: 'Anilist',
        version: '1.0.0',
        baseUrl: 'https://graphql.anilist.co',
        searchURL: 'https://graphql.anilist.co',
        searchList: 'list',
        searchName: 'name',
        searchResult: 'url',
        chapterRoads: '',
        chapterResult: '',
        userAgent: AppConstants.defaultUserAgent,
        enabled: true,
      ),
      // Bangumi API 插件 - 搜索动漫元数据（中文源，需要网络可达）
      Plugin(
        api: 'bangumi',
        name: 'Bangumi 番组计划',
        version: '1.0.0',
        baseUrl: 'https://api.bgm.tv',
        searchURL:
            'https://api.bgm.tv/search/subject/{keyword}?type=2&max_results=25',
        searchList: 'list',
        searchName: 'name',
        searchResult: 'url',
        chapterRoads: '',
        chapterResult: '',
        userAgent: AppConstants.defaultUserAgent,
        enabled: true,
      ),
      // 苹果CMS模板 - 用户可自行配置
      Plugin(
        api: 'maccms_template',
        name: '动漫源模板（点击配置）',
        version: '1.0.0',
        baseUrl: 'https://example.com',
        searchURL: 'https://example.com/search.html?wd={keyword}',
        searchList: '.public-list-box',
        searchName: '.time-title',
        searchResult: '.public-list-exp',
        chapterRoads: '.playlist li',
        chapterResult: 'a',
        userAgent: AppConstants.defaultUserAgent,
        enabled: false,
      ),
      // 非凡资源 CMS API（可用，动漫分类 t=30）
      Plugin(
        api: 'cms_ffzy',
        name: '非凡资源',
        version: '1.0.0',
        baseUrl: 'https://cj.ffzyapi.com',
        searchURL:
            'https://cj.ffzyapi.com/api.php/provide/vod/?ac=videolist&wd={keyword}',
        searchList: 'list',
        searchName: 'vod_name',
        searchResult: 'vod_id',
        chapterRoads: '',
        chapterResult: '',
        userAgent: AppConstants.defaultUserAgent,
        enabled: true,
        catalog: PluginCatalogDefaults.ffzy,
      ),
      // 樱花动漫 CMS API
      Plugin(
        api: 'cms_yinhua',
        name: '樱花动漫',
        version: '1.0.0',
        baseUrl: 'https://www.yinhuadm.xyz',
        searchURL:
            'https://www.yinhuadm.xyz/api.php/provide/vod/?ac=videolist&wd={keyword}',
        searchList: 'list',
        searchName: 'vod_name',
        searchResult: 'vod_id',
        chapterRoads: '',
        chapterResult: '',
        userAgent: AppConstants.defaultUserAgent,
        enabled: true,
        catalog: PluginCatalogDefaults.yinhua,
      ),
    ];
  }

  /// 把缺失的默认插件与内建目录配置合并进现有列表。
  /// 返回合并后的列表与是否发生变更。
  static MergeResult mergeInto(List<Plugin> existing) {
    final merged = List<Plugin>.of(existing);
    var changed = false;
    for (final defaultPlugin in createDefaultPlugins()) {
      final exists = merged.any((p) => p.api == defaultPlugin.api);
      if (!exists) {
        merged.add(defaultPlugin);
        changed = true;
      }
    }
    for (final plugin in merged) {
      if (plugin.catalog != null) continue;
      final builtIn = PluginCatalogDefaults.forPlugin(
        plugin.api,
        plugin.baseUrl,
      );
      if (builtIn != null) {
        plugin.catalog = builtIn;
        changed = true;
      }
    }
    return MergeResult(plugins: merged, changed: changed);
  }
}

class MergeResult {
  const MergeResult({required this.plugins, required this.changed});

  final List<Plugin> plugins;
  final bool changed;
}
