import '../../models/anime.dart';
import '../../models/plugin.dart';
import '../http/http_client.dart';
import '../../utils/logger.dart';

class CmsApiService {
  final HttpClient http;

  CmsApiService(this.http);

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

  /// 修复封面URL：相对路径拼上baseUrl
  static String? fixCoverUrl(String? url, String baseUrl) {
    if (url == null || url.isEmpty || url == 'null') return null;
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    if (url.startsWith('//')) return 'https:$url';
    // 相对路径：拼上baseUrl
    return '$baseUrl/${url.startsWith('/') ? url.substring(1) : url}';
  }

  String stripHtml(String html) {
    return html.replaceAll(RegExp(r'<[^>]*>'), '').replaceAll('&amp;', '&').trim();
  }

  Future<List<Anime>> searchCms(Plugin plugin, String keyword, List<Plugin> plugins) async {
    try {
      final url = plugin.searchURL.replaceAll('{keyword}', Uri.encodeComponent(keyword));
      Log.d('CMS', '搜索 ${plugin.name}: $url');
      final headers = <String, String>{'Accept': 'application/json'};
      if (plugin.userAgent.isNotEmpty) headers['User-Agent'] = plugin.userAgent;
      final data = await http.getJson(url, headers: headers);
      if (data is! Map<String, dynamic>) return [];
      final list = data['list'] as List? ?? [];

      // 获取该源的动漫分类ID，用于过滤非动漫内容
      final animeTypeIds = (cmsCategories[plugin.api] ?? [])
          .map((c) => c['id'] as int).toSet();

      final results = <Anime>[];
      for (final item in list) {
        if (item is! Map<String, dynamic>) continue;
        final name = item['vod_name']?.toString() ?? '';
        final id = item['vod_id']?.toString() ?? '';
        if (name.isEmpty || id.isEmpty) continue;

        // 过滤：只保留动漫分类
        if (animeTypeIds.isNotEmpty) {
          final typeId = int.tryParse(item['type_id']?.toString() ?? '') ?? 0;
          if (typeId > 0 && !animeTypeIds.contains(typeId)) continue;
        }

        results.add(Anime(
          name: name,
          url: '${plugin.api}:$id',
          cover: fixCoverUrl(item['vod_pic']?.toString(), plugin.baseUrl),
          description: item['vod_remarks']?.toString(),
          sourcePlugin: plugin.api,
        ));
      }
      Log.d('CMS', '${plugin.name} 找到 ${results.length} 条结果');
      return results;
    } catch (e) {
      Log.e('CMS', '搜索失败', e);
      return [];
    }
  }

  Future<Map<String, dynamic>?> getCmsDetail(String animeUrl, String sourcePlugin, List<Plugin> plugins) async {
    try {
      final parts = animeUrl.split(':');
      if (parts.length < 2) return null;
      final cmsId = parts[1];
      if (plugins.isEmpty) return null;
      final plugin = plugins.firstWhere((p) => p.api == sourcePlugin, orElse: () => plugins.first);
      final url = '${plugin.baseUrl}/api.php/provide/vod/?ac=detail&ids=$cmsId';
      Log.d('CMS', '获取详情: $url');
      final data = await http.getJson(url, headers: {'User-Agent': plugin.userAgent});
      if (data is! Map<String, dynamic>) return null;
      final list = data['list'] as List? ?? [];
      if (list.isEmpty) return null;
      final item = list.first as Map<String, dynamic>;
      final playUrl = item['vod_play_url']?.toString() ?? '';
      final playFrom = item['vod_play_from']?.toString() ?? '';
      final episodes = playUrl.isNotEmpty ? parseCmsPlayUrl(playUrl, playFrom) : <Map<String, dynamic>>[];
      final tags = (item['vod_class']?.toString() ?? '').split(',').where((t) => t.trim().isNotEmpty).toList();
      return {
        'name': item['vod_name']?.toString() ?? '',
        'name_cn': item['vod_name']?.toString() ?? '',
        'name_ja': item['vod_sub']?.toString() ?? '',
        'summary': stripHtml(item['vod_content']?.toString() ?? item['vod_blurb']?.toString() ?? ''),
        'cover': fixCoverUrl(item['vod_pic']?.toString(), plugin.baseUrl),
        'rating': double.tryParse(item['vod_score']?.toString() ?? ''),
        'tags': tags,
        'date': item['vod_pubdate']?.toString() ?? item['vod_year']?.toString() ?? '',
        'platform': item['vod_area']?.toString() ?? '',
        'total_episodes': int.tryParse(item['vod_total']?.toString() ?? '') ?? episodes.length,
        'episodes': episodes,
        'status': item['vod_remarks']?.toString(),
      };
    } catch (e) {
      Log.e('CMS', '获取详情失败', e);
      return null;
    }
  }

  Future<List<Episode>> getCmsEpisodes(String animeUrl, String sourcePlugin, List<Plugin> plugins) async {
    final detail = await getCmsDetail(animeUrl, sourcePlugin, plugins);
    if (detail == null) return [];
    final eps = detail['episodes'] as List? ?? [];
    return eps.map((ep) => Episode(
      name: ep['name'] ?? '第${ep['sort']}集',
      url: ep['url'] ?? '',
      index: ep['sort'] ?? 0,
    )).toList();
  }

  List<Map<String, dynamic>> parseCmsPlayUrl(String playUrl, String playFrom) {
    final episodes = <Map<String, dynamic>>[];
    final groups = playUrl.split(r'$$$');
    int preferredGroup = 0;
    for (int i = 0; i < groups.length; i++) {
      if (groups[i].contains('.m3u8')) { preferredGroup = i; break; }
    }
    if (preferredGroup < groups.length) {
      final group = groups[preferredGroup];
      int epNum = 1;
      for (final ep in group.split('#')) {
        final idx = ep.indexOf(r'$');
        if (idx > 0) {
          final title = ep.substring(0, idx).trim();
          final url = ep.substring(idx + 1).trim();
          episodes.add({'sort': epNum, 'name': title.isEmpty ? '第$epNum集' : title, 'url': url});
          epNum++;
        }
      }
    }
    return episodes;
  }

  Future<List<Map<String, dynamic>>> getCmsLatest({String? pluginApi, int page = 1, required List<Plugin> plugins}) async {
    final api = pluginApi ?? 'cms_yinhua';
    if (plugins.isEmpty) return [];
    final plugin = plugins.firstWhere((p) => p.api == api, orElse: () => plugins.firstWhere((p) => p.api.startsWith('cms_'), orElse: () => plugins.first));
    try {
      final catId = api == 'cms_ffzy' ? '30' : '10';
      final url = '${plugin.baseUrl}/api.php/provide/vod/?ac=videolist&t=$catId&pg=$page';
      Log.d('CMS', '首页数据: $url');
      final headers = <String, String>{'Accept': 'application/json'};
      if (plugin.userAgent.isNotEmpty) headers['User-Agent'] = plugin.userAgent;
      final data = await http.getJson(url, headers: headers);
      if (data is! Map<String, dynamic>) return [];
      final list = data['list'] as List? ?? [];
      return list.whereType<Map<String, dynamic>>().map((item) => {
        'id': item['vod_id']?.toString() ?? '',
        'name': item['vod_name']?.toString() ?? '',
        'cover': fixCoverUrl(item['vod_pic']?.toString(), plugin.baseUrl),
        'score': double.tryParse(item['vod_score']?.toString() ?? ''),
        'status': item['vod_remarks']?.toString() ?? '',
        'genres': (item['vod_class']?.toString() ?? '').split(',').where((g) => g.trim().isNotEmpty).take(3).toList(),
        'year': item['vod_year']?.toString() ?? '',
        'area': item['vod_area']?.toString() ?? '',
        'vod_time': item['vod_time']?.toString() ?? '',
        'url': '${plugin.api}:${item['vod_id']}',
        'sourcePlugin': plugin.api,
      }).toList();
    } catch (e) {
      Log.e('CMS', '首页数据获取失败', e);
      return [];
    }
  }

  /// 按分类获取CMS列表（带分页）
  Future<Map<String, dynamic>> getCmsByCategory({
    required String pluginApi,
    required int categoryId,
    int page = 1,
    String? sort, // hits/time/score
    required List<Plugin> plugins,
  }) async {
    if (plugins.isEmpty) return {'list': <Map<String, dynamic>>[], 'total': 0, 'pages': 0};
    final plugin = plugins.firstWhere(
      (p) => p.api == pluginApi,
      orElse: () => plugins.firstWhere((p) => p.api.startsWith('cms_'), orElse: () => plugins.first),
    );
    try {
      var url = '${plugin.baseUrl}/api.php/provide/vod/?ac=videolist&t=$categoryId&pg=$page';
      if (sort != null) url += '&sort=$sort';
      Log.d('CMS', '分类列表: $url');
      final headers = <String, String>{'Accept': 'application/json'};
      if (plugin.userAgent.isNotEmpty) headers['User-Agent'] = plugin.userAgent;
      final data = await http.getJson(url, headers: headers);
      if (data is! Map<String, dynamic>) return {'list': <Map<String, dynamic>>[], 'total': 0, 'pages': 0};
      final list = data['list'] as List? ?? [];
      final total = data['total'] as int? ?? 0;
      final pages = data['pagecount'] as int? ?? 0;
      return {
        'list': list.whereType<Map<String, dynamic>>().map((item) => {
          'id': item['vod_id']?.toString() ?? '',
          'name': item['vod_name']?.toString() ?? '',
          'cover': fixCoverUrl(item['vod_pic']?.toString(), plugin.baseUrl),
          'score': double.tryParse(item['vod_score']?.toString() ?? ''),
          'status': item['vod_remarks']?.toString() ?? '',
          'genres': (item['vod_class']?.toString() ?? '').split(',').where((g) => g.trim().isNotEmpty).take(3).toList(),
          'year': item['vod_year']?.toString() ?? '',
          'area': item['vod_area']?.toString() ?? '',
          'url': '${plugin.api}:${item['vod_id']}',
          'sourcePlugin': plugin.api,
        }).toList(),
        'total': total,
        'pages': pages,
      };
    } catch (e) {
      Log.e('CMS', '分类列表获取失败', e);
      return {'list': <Map<String, dynamic>>[], 'total': 0, 'pages': 0};
    }
  }

  /// 获取CMS排行榜（按评分排序，客户端排序）
  Future<List<Map<String, dynamic>>> getCmsRanking({String? pluginApi, int pages = 3, required List<Plugin> plugins}) async {
    final api = pluginApi ?? 'cms_yinhua';
    final categories = cmsCategories[api] ?? [];
    if (categories.isEmpty) return [];
    final catId = categories.first['id'] as int;

    final allItems = <Map<String, dynamic>>[];
    for (int pg = 1; pg <= pages; pg++) {
      final result = await getCmsByCategory(pluginApi: api, categoryId: catId, page: pg, plugins: plugins);
      allItems.addAll(result['list'] as List<Map<String, dynamic>>);
    }

    // 按评分降序排序
    allItems.sort((a, b) {
      final sa = a['score'] as double? ?? 0;
      final sb = b['score'] as double? ?? 0;
      return sb.compareTo(sa);
    });

    return allItems.take(30).toList();
  }
}
