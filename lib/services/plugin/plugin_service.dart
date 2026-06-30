import 'dart:convert';
import '../../utils/logger.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../../models/plugin.dart';
import '../../models/anime.dart';
import '../../utils/constants.dart';
import '../http/http_client.dart';
import '../parser/xpath_parser.dart';
import '../jikan/jikan_service.dart';

class PluginService {
  static final PluginService _instance = PluginService._();
  factory PluginService() => _instance;
  PluginService._();

  final HttpClient _http = HttpClient();
  List<Plugin> _plugins = [];
  List<Plugin> get plugins => List.unmodifiable(_plugins);

  /// 初始化：加载插件
  Future<void> init() async {
    final file = await _getPluginFile();

    if (await file.exists()) {
      try {
        final json = jsonDecode(await file.readAsString()) as List;
        _plugins = json
            .map((e) => Plugin.fromJson(e as Map<String, dynamic>))
            .toList();
        Log.d('Plugin', '加载了 ${_plugins.length} 个插件');
      } catch (e) {
        Log.d('Plugin', '加载插件失败: $e');
        _plugins = [];
      }
    } else {
      Log.d('Plugin', '无插件文件，使用空列表');
    }

    // 确保默认插件存在（合并缺失的）
    final defaults = _createDefaultPlugins();
    bool changed = false;
    for (final defaultPlugin in defaults) {
      final exists = _plugins.any((p) => p.api == defaultPlugin.api);
      if (!exists) {
        _plugins.add(defaultPlugin);
        changed = true;
        Log.d('Plugin', '添加默认插件: ${defaultPlugin.name}');
      }
    }
    if (changed) {
      await _savePlugins();
    }
  }

  /// 获取已启用的插件
  List<Plugin> getEnabledPlugins() {
    return _plugins.where((p) => p.enabled).toList();
  }

  /// 搜索所有已启用的插件
  Future<List<Anime>> searchAll(String keyword) async {
    final enabledPlugins = getEnabledPlugins();
    if (enabledPlugins.isEmpty) {
      Log.d('Plugin', '没有已启用的插件');
      return [];
    }

    final allResults = <Anime>[];
    
    // 并行搜索所有插件（每个插件最多10秒超时）
    final futures = enabledPlugins.map((plugin) =>
      _searchPlugin(plugin, keyword).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          Log.d('Plugin', '搜索 ${plugin.name} 超时');
          return <Anime>[];
        },
      ),
    );
    final results = await Future.wait(futures, eagerError: false);
    
    for (final list in results) {
      allResults.addAll(list);
    }

    return allResults;
  }

  /// 仅搜索 CMS 源（不搜索其他插件，速度更快）
  Future<List<Anime>> searchCmsOnly(String keyword) async {
    final cmsPlugins = getEnabledPlugins().where((p) => p.api.startsWith('cms_')).toList();
    if (cmsPlugins.isEmpty) return [];

    final allResults = <Anime>[];
    final futures = cmsPlugins.map((plugin) =>
      _searchPlugin(plugin, keyword).timeout(
        const Duration(seconds: 10),
        onTimeout: () => <Anime>[],
      ),
    );
    final results = await Future.wait(futures, eagerError: false);
    for (final list in results) {
      allResults.addAll(list);
    }
    return allResults;
  }

  /// 仅搜索 Bangumi（用于获取中文名称做桥接）
  Future<List<Anime>> searchBangumi(String keyword) async {
    final bangumiPlugin = _plugins.where((p) => p.api == 'bangumi' && p.enabled).firstOrNull;
    if (bangumiPlugin == null) return [];
    return await _searchPlugin(bangumiPlugin, keyword).timeout(
      const Duration(seconds: 8),
      onTimeout: () => <Anime>[],
    );
  }

  /// 搜索单个插件
  Future<List<Anime>> _searchPlugin(Plugin plugin, String keyword) async {
    try {
      // 构建搜索URL
      final searchUrl = plugin.searchURL.replaceAll('{keyword}', Uri.encodeComponent(keyword));
      
      Log.d('Plugin', '搜索 ${plugin.name}: $searchUrl');
      
      // 发送请求
      final headers = <String, String>{};
      if (plugin.userAgent.isNotEmpty) {
        headers['User-Agent'] = plugin.userAgent;
      }
      if (plugin.referer != null && plugin.referer!.isNotEmpty) {
        headers['Referer'] = plugin.referer!;
      }

      // 判断 API 类型
      if (_isJikanApi(plugin)) {
        return await JikanService().searchAnime(keyword);
      }
      if (_isAnilistApi(plugin)) {
        return await _searchAnilist(keyword);
      }
      if (_isCmsApi(plugin)) {
        return await _searchCms(plugin, keyword);
      }
      if (_isJsonApi(plugin)) {
        return await _searchJsonApi(plugin, searchUrl, headers);
      }

      // HTML 解析模式
      final html = await _http.getHtml(searchUrl, headers: headers);
      final results = XPathParser.parseSearchResults(
        html,
        listSelector: plugin.searchList,
        nameSelector: plugin.searchName,
        linkSelector: plugin.searchResult,
        baseUrl: plugin.baseUrl,
      );

      return results.map((r) => Anime(
        name: r.name ?? '',
        url: r.url ?? '',
        cover: r.cover,
        description: r.description,
        sourcePlugin: plugin.api,
      )).where((a) => a.name.isNotEmpty && a.url.isNotEmpty).toList();
    } catch (e) {
      Log.d('Plugin', '搜索 ${plugin.name} 失败: $e');
      return [];
    }
  }

  /// 判断是否是 JSON API（Bangumi等）
  bool _isJsonApi(Plugin plugin) {
    return plugin.baseUrl.contains('api.bgm.tv') ||
           plugin.searchList == 'list' ||
           plugin.searchURL.contains('api.');
  }

  /// 判断是否是 Anilist GraphQL API
  bool _isAnilistApi(Plugin plugin) {
    return plugin.api == 'anilist' ||
           plugin.baseUrl.contains('anilist.co');
  }

  /// 判断是否是 CMS 采集站 API（maccms / ffzy 等）
  bool _isCmsApi(Plugin plugin) {
    return plugin.api.startsWith('cms_') ||
           plugin.searchURL.contains('api.php/provide/vod');
  }

  /// 判断是否是 Jikan API (MyAnimeList)
  bool _isJikanApi(Plugin plugin) {
    return plugin.api == 'jikan' ||
           plugin.baseUrl.contains('jikan.moe');
  }

  /// JSON API 搜索（Bangumi等）
  Future<List<Anime>> _searchJsonApi(Plugin plugin, String url, Map<String, String> headers) async {
    Log.d('Plugin', 'JSON API 请求: $url');
    final data = await _http.getJson(url, headers: headers);
    final results = <Anime>[];

    Log.d('Plugin', '响应类型: ${data.runtimeType}');

    if (data is Map<String, dynamic>) {
      Log.d('Plugin', '响应keys: ${data.keys.toList()}');
      
      if (data.containsKey('list')) {
        // Bangumi API 格式
        final list = data['list'] as List? ?? [];
        Log.d('Plugin', '找到 ${list.length} 条结果');
        
        for (final item in list) {
          if (item is Map<String, dynamic>) {
            // 优先用中文名，没有则用日文名
            String name = '';
            final nameCn = item['name_cn']?.toString() ?? '';
            final nameJa = item['name']?.toString() ?? '';
            if (nameCn.isNotEmpty) {
              name = nameCn;
            } else if (nameJa.isNotEmpty) {
              name = nameJa;
            }
            
            final id = item['id']?.toString() ?? '';
            final subjectUrl = 'https://bgm.tv/subject/$id';
            
            String? cover;
            final images = item['images'] as Map<String, dynamic>?;
            if (images != null) {
              cover = images['large']?.toString() ?? images['medium']?.toString();
            }

            final summary = item['summary']?.toString() ?? '';

            if (name.isNotEmpty) {
              results.add(Anime(
                name: name,
                url: subjectUrl,
                cover: cover,
                description: summary.isNotEmpty ? summary : null,
                sourcePlugin: plugin.api,
              ));
            }
          }
        }
      }
    } else if (data is List) {
      // 直接是数组格式
      for (final item in data) {
        if (item is Map<String, dynamic>) {
          results.add(Anime(
            name: item['name']?.toString() ?? '',
            url: item['url']?.toString() ?? '',
            cover: item['cover']?.toString(),
            description: item['description']?.toString(),
            sourcePlugin: plugin.api,
          ));
        }
      }
    }

    Log.d('Plugin', '解析完成: ${results.length} 条有效结果');
    return results.where((a) => a.name.isNotEmpty).toList();
  }

  // ============================================================
  // CMS 采集站 API
  // ============================================================

  Future<List<Anime>> _searchCms(Plugin plugin, String keyword) async {
    try {
      final url = plugin.searchURL.replaceAll('{keyword}', Uri.encodeComponent(keyword));
      Log.d('CMS', '搜索 ${plugin.name}: $url');
      final headers = <String, String>{'Accept': 'application/json'};
      if (plugin.userAgent.isNotEmpty) headers['User-Agent'] = plugin.userAgent;
      final data = await _http.getJson(url, headers: headers);
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
          cover: _fixCoverUrl(item['vod_pic']?.toString(), plugin.baseUrl),
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

  Future<Map<String, dynamic>?> _getCmsDetail(String animeUrl, String sourcePlugin) async {
    try {
      final parts = animeUrl.split(':');
      if (parts.length < 2) return null;
      final cmsId = parts[1];
      if (_plugins.isEmpty) return null;
      final plugin = _plugins.firstWhere((p) => p.api == sourcePlugin, orElse: () => _plugins.first);
      final url = '${plugin.baseUrl}/api.php/provide/vod/?ac=detail&ids=$cmsId';
      Log.d('CMS', '获取详情: $url');
      final data = await _http.getJson(url, headers: {'User-Agent': plugin.userAgent});
      if (data is! Map<String, dynamic>) return null;
      final list = data['list'] as List? ?? [];
      if (list.isEmpty) return null;
      final item = list.first as Map<String, dynamic>;
      final playUrl = item['vod_play_url']?.toString() ?? '';
      final playFrom = item['vod_play_from']?.toString() ?? '';
      final episodes = playUrl.isNotEmpty ? _parseCmsPlayUrl(playUrl, playFrom) : <Map<String, dynamic>>[];
      final tags = (item['vod_class']?.toString() ?? '').split(',').where((t) => t.trim().isNotEmpty).toList();
      return {
        'name': item['vod_name']?.toString() ?? '',
        'name_cn': item['vod_name']?.toString() ?? '',
        'name_ja': item['vod_sub']?.toString() ?? '',
        'summary': _stripHtml(item['vod_content']?.toString() ?? item['vod_blurb']?.toString() ?? ''),
        'cover': _fixCoverUrl(item['vod_pic']?.toString(), plugin.baseUrl),
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

  Future<List<Episode>> _getCmsEpisodes(String animeUrl, String sourcePlugin) async {
    final detail = await _getCmsDetail(animeUrl, sourcePlugin);
    if (detail == null) return [];
    final eps = detail['episodes'] as List? ?? [];
    return eps.map((ep) => Episode(
      name: ep['name'] ?? '第${ep['sort']}集',
      url: ep['url'] ?? '',
      index: ep['sort'] ?? 0,
    )).toList();
  }

  List<Map<String, dynamic>> _parseCmsPlayUrl(String playUrl, String playFrom) {
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

  Future<List<Map<String, dynamic>>> getCmsLatest({String? pluginApi, int page = 1}) async {
    final api = pluginApi ?? 'cms_yinhua';
    if (_plugins.isEmpty) return [];
    final plugin = _plugins.firstWhere((p) => p.api == api, orElse: () => _plugins.firstWhere((p) => p.api.startsWith('cms_'), orElse: () => _plugins.first));
    try {
      final catId = api == 'cms_ffzy' ? '30' : '10';
      final url = '${plugin.baseUrl}/api.php/provide/vod/?ac=videolist&t=$catId&pg=$page';
      Log.d('CMS', '首页数据: $url');
      final headers = <String, String>{'Accept': 'application/json'};
      if (plugin.userAgent.isNotEmpty) headers['User-Agent'] = plugin.userAgent;
      final data = await _http.getJson(url, headers: headers);
      if (data is! Map<String, dynamic>) return [];
      final list = data['list'] as List? ?? [];
      return list.whereType<Map<String, dynamic>>().map((item) => {
        'id': item['vod_id']?.toString() ?? '',
        'name': item['vod_name']?.toString() ?? '',
        'cover': _fixCoverUrl(item['vod_pic']?.toString(), plugin.baseUrl),
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

  // ============================================================
  // CMS 分类浏览
  // ============================================================

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

  /// 按分类获取CMS列表（带分页）
  Future<Map<String, dynamic>> getCmsByCategory({
    required String pluginApi,
    required int categoryId,
    int page = 1,
    String? sort, // hits/time/score
  }) async {
    if (_plugins.isEmpty) return {'list': <Map<String, dynamic>>[], 'total': 0, 'pages': 0};
    final plugin = _plugins.firstWhere(
      (p) => p.api == pluginApi,
      orElse: () => _plugins.firstWhere((p) => p.api.startsWith('cms_'), orElse: () => _plugins.first),
    );
    try {
      var url = '${plugin.baseUrl}/api.php/provide/vod/?ac=videolist&t=$categoryId&pg=$page';
      if (sort != null) url += '&sort=$sort';
      Log.d('CMS', '分类列表: $url');
      final headers = <String, String>{'Accept': 'application/json'};
      if (plugin.userAgent.isNotEmpty) headers['User-Agent'] = plugin.userAgent;
      final data = await _http.getJson(url, headers: headers);
      if (data is! Map<String, dynamic>) return {'list': <Map<String, dynamic>>[], 'total': 0, 'pages': 0};
      final list = data['list'] as List? ?? [];
      final total = data['total'] as int? ?? 0;
      final pages = data['pagecount'] as int? ?? 0;
      return {
        'list': list.whereType<Map<String, dynamic>>().map((item) => {
          'id': item['vod_id']?.toString() ?? '',
          'name': item['vod_name']?.toString() ?? '',
          'cover': _fixCoverUrl(item['vod_pic']?.toString(), plugin.baseUrl),
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
  Future<List<Map<String, dynamic>>> getCmsRanking({String? pluginApi, int pages = 3}) async {
    final api = pluginApi ?? 'cms_yinhua';
    final categories = cmsCategories[api] ?? [];
    if (categories.isEmpty) return [];
    final catId = categories.first['id'] as int;

    final allItems = <Map<String, dynamic>>[];
    for (int pg = 1; pg <= pages; pg++) {
      final result = await getCmsByCategory(pluginApi: api, categoryId: catId, page: pg);
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

  /// 修复封面URL：相对路径拼上baseUrl
  static String? _fixCoverUrl(String? url, String baseUrl) {
    if (url == null || url.isEmpty || url == 'null') return null;
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    if (url.startsWith('//')) return 'https:$url';
    // 相对路径：拼上baseUrl
    return '$baseUrl/${url.startsWith('/') ? url.substring(1) : url}';
  }

  String _stripHtml(String html) {
    return html.replaceAll(RegExp(r'<[^>]*>'), '').replaceAll('&amp;', '&').trim();
  }

  // ============================================================
  // Anilist GraphQL API
  // ============================================================

  static const _anilistEndpoint = 'https://graphql.anilist.co';

  Future<List<Anime>> _searchAnilist(String keyword) async {
    const query = r'''
      query ($search: String) {
        Page(perPage: 10) {
          media(search: $search, type: ANIME) {
            id
            title { romaji native english }
            coverImage { large medium }
            description
          }
        }
      }
    ''';
    try {
      Log.d('Anilist', '搜索: $keyword');
      final data = await _http.postJson(_anilistEndpoint, data: {
        'query': query,
        'variables': {'search': keyword},
      });
      if (data is! Map<String, dynamic>) return [];
      final mediaList = data['data']?['Page']?['media'] as List?;
      if (mediaList == null || mediaList.isEmpty) return [];
      return mediaList.map((media) {
        final title = media['title'];
        final name = title['native']?.toString() ?? title['romaji']?.toString() ?? '';
        return Anime(
          name: name,
          url: 'anilist:${media['id']}',
          cover: media['coverImage']?['large']?.toString(),
          description: media['description']?.toString(),
          sourcePlugin: 'anilist',
        );
      }).where((a) => a.name.isNotEmpty).toList();
    } catch (e) {
      Log.e('Anilist', '搜索失败', e);
      return [];
    }
  }

  Future<Map<String, dynamic>?> _getAnilistDetail(String animeUrl) async {
    final id = animeUrl.replaceAll('anilist:', '');
    const query = r'''
      query ($id: Int) {
        Media(id: $id, type: ANIME) {
          id
          title { romaji native english }
          coverImage { large medium }
          description
          episodes
          status
          genres
          averageScore
        }
      }
    ''';
    try {
      Log.d('Anilist', '获取详情: ID=$id');
      final data = await _http.postJson(_anilistEndpoint, data: {
        'query': query,
        'variables': {'id': int.parse(id)},
      });
      if (data is! Map<String, dynamic>) return null;
      final media = data['data']?['Media'];
      if (media == null) return null;
      final title = media['title'];
      return {
        'name': title['native']?.toString() ?? title['romaji']?.toString() ?? '',
        'name_cn': title['native']?.toString() ?? '',
        'name_ja': title['romaji']?.toString() ?? '',
        'summary': media['description']?.toString() ?? '',
        'cover': media['coverImage']?['large']?.toString(),
        'rating': media['averageScore'] != null ? (media['averageScore'] as int) / 10.0 : null,
        'tags': (media['genres'] as List?)?.cast<String>() ?? [],
        'status': media['status']?.toString(),
        'total_episodes': media['episodes'],
      };
    } catch (e) {
      Log.e('Anilist', '获取详情失败', e);
      return null;
    }
  }

  Future<List<Episode>> _getAnilistEpisodes(String animeUrl) async {
    final detail = await _getAnilistDetail(animeUrl);
    if (detail == null) return [];
    final totalEps = detail['total_episodes'] as int? ?? 12;
    return List.generate(totalEps, (i) => Episode(
      name: '第${i + 1}集',
      url: '',
      index: i + 1,
    ));
  }

  /// 获取动漫详情
  Future<Map<String, dynamic>?> getDetail(Anime anime) async {
    if (anime.sourcePlugin == 'jikan') {
      final malId = JikanService.extractMalId(anime.url);
      if (malId == null) return null;
      return await JikanService().getAnimeDetails(malId);
    }
    if (anime.sourcePlugin == 'anilist') {
      return await _getAnilistDetail(anime.url);
    }
    if (anime.sourcePlugin == 'bangumi') {
      return await _getBangumiDetail(anime.url);
    }
    if (anime.sourcePlugin.startsWith('cms_')) {
      return await _getCmsDetail(anime.url, anime.sourcePlugin);
    }
    return null;
  }

  /// 获取Bangumi详情
  Future<Map<String, dynamic>?> _getBangumiDetail(String subjectUrl) async {
    try {
      // 从URL提取subject ID
      final match = RegExp(r'/subject/(\d+)').firstMatch(subjectUrl);
      if (match == null) return null;
      final id = match.group(1);
      
      final headers = {'User-Agent': AppConstants.defaultUserAgent};
      
      // 获取详情
      final detailUrl = 'https://api.bgm.tv/v0/subjects/$id';
      Log.d('Plugin', '获取Bangumi详情: $detailUrl');
      final detail = await _http.getJson(detailUrl, headers: headers);
      
      // 获取集数（用旧API，返回更完整）
      final epsUrl = 'https://api.bgm.tv/subject/$id?responseGroup=large';
      Log.d('Plugin', '获取Bangumi集数: $epsUrl');
      final epsData = await _http.getJson(epsUrl, headers: headers);
      
      return {
        'name': detail['name_cn']?.toString().isNotEmpty == true
            ? detail['name_cn']
            : detail['name'],
        'name_cn': detail['name_cn'] ?? '',
        'name_ja': detail['name'] ?? '',
        'summary': detail['summary'] ?? '',
        'cover': detail['images']?['large'] ?? detail['images']?['medium'],
        'rating': detail['rating']?['score'],
        'rating_count': detail['rating']?['total'],
        'rank': detail['rating']?['rank'],
        'tags': (detail['tags'] as List?)
            ?.take(8)
            .map((t) => t['name']?.toString() ?? '')
            .where((t) => t.isNotEmpty)
            .toList(),
        'date': detail['date'] ?? epsData['air_date'] ?? '',
        'platform': detail['platform'] ?? '',
        'total_episodes': detail['total_episodes'],
        'episodes': (epsData['eps'] as List?)
            ?.where((ep) => ep['type'] == 0)  // 只要正片
            .map((ep) => {
              'sort': ep['sort'],
              'name': ep['name_cn']?.toString().isNotEmpty == true
                  ? ep['name_cn']
                  : ep['name'],
              'airdate': ep['airdate'],
              'duration': ep['duration'],
            })
            .toList(),
      };
    } catch (e) {
      Log.d('Plugin', '获取Bangumi详情失败: $e');
      return null;
    }
  }

  /// 获取动漫章节列表
  Future<List<Episode>> getEpisodes(Anime anime) async {
    // Jikan 模式（不提供播放源，生成占位集数）
    if (anime.sourcePlugin == 'jikan') {
      final malId = JikanService.extractMalId(anime.url);
      if (malId == null) return [];
      final detail = await JikanService().getAnimeDetails(malId);
      if (detail == null) return [];
      final totalEps = detail['total_episodes'] as int? ?? 12;
      return List.generate(totalEps, (i) => Episode(
        name: '第${i + 1}话',
        url: '', // Jikan 不提供播放源，需配合 CMS 源使用
        index: i + 1,
      ));
    }

    // Anilist 模式
    if (anime.sourcePlugin == 'anilist') {
      return await _getAnilistEpisodes(anime.url);
    }

    // CMS 模式
    if (anime.sourcePlugin.startsWith('cms_')) {
      return await _getCmsEpisodes(anime.url, anime.sourcePlugin);
    }

    // Bangumi API 模式
    if (anime.sourcePlugin == 'bangumi') {
      final detail = await getDetail(anime);
      if (detail == null) return [];
      final eps = detail['episodes'] as List? ?? [];
      return eps.map((ep) => Episode(
        name: ep['name'] ?? '第${ep['sort']}集',
        url: '${anime.url}/ep/${ep['sort']}',
        index: ep['sort'] ?? 0,
      )).toList();
    }

    // HTML 解析模式
    if (_plugins.isEmpty) return [];
    final plugin = _plugins.firstWhere(
      (p) => p.api == anime.sourcePlugin,
      orElse: () => _plugins.first,
    );

    try {
      Log.d('Plugin', '获取章节: ${anime.url}');
      
      final headers = <String, String>{};
      if (plugin.userAgent.isNotEmpty) {
        headers['User-Agent'] = plugin.userAgent;
      }
      if (plugin.referer != null && plugin.referer!.isNotEmpty) {
        headers['Referer'] = plugin.referer!;
      }

      final html = await _http.getHtml(anime.url, headers: headers);

      final results = XPathParser.parseEpisodes(
        html,
        listSelector: plugin.chapterRoads,
        nameSelector: 'a',
        linkSelector: 'a',
        baseUrl: plugin.baseUrl,
      );

      return results.map((r) => Episode(
        name: r.name,
        url: r.url,
        index: r.index,
      )).toList();
    } catch (e) {
      Log.d('Plugin', '获取章节失败: $e');
      return [];
    }
  }

  /// 获取视频源URL
  Future<List<String>> getVideoUrls(String episodeUrl, Plugin plugin) async {
    try {
      Log.d('Plugin', '获取视频源: $episodeUrl');
      
      // CMS 插件的视频源已经在详情中获取，直接返回
      if (_isCmsApi(plugin)) {
        // episodeUrl 对于 CMS 来说已经是直链
        return [episodeUrl];
      }

      final headers = <String, String>{};
      if (plugin.userAgent.isNotEmpty) {
        headers['User-Agent'] = plugin.userAgent;
      }
      if (plugin.referer != null && plugin.referer!.isNotEmpty) {
        headers['Referer'] = plugin.referer!;
      }

      final html = await _http.getHtml(episodeUrl, headers: headers);

      // 先用选择器尝试
      final sources = XPathParser.parseVideoSources(
        html,
        listSelector: plugin.chapterResult,
        nameSelector: 'a',
        linkSelector: 'a',
        baseUrl: plugin.baseUrl,
      );

      if (sources.isNotEmpty) {
        return sources.map((s) => s.url).toList();
      }

      // 降级：正则提取视频URL
      return XPathParser.parseVideoUrls(html);
    } catch (e) {
      Log.d('Plugin', '获取视频源失败: $e');
      return [];
    }
  }

  /// 添加插件
  Future<void> addPlugin(Plugin plugin) async {
    _plugins.add(plugin);
    await _savePlugins();
  }

  /// 删除插件
  Future<void> removePlugin(String api) async {
    _plugins.removeWhere((p) => p.api == api);
    await _savePlugins();
  }

  /// 切换插件启用状态
  Future<void> togglePlugin(String api) async {
    final index = _plugins.indexWhere((p) => p.api == api);
    if (index >= 0) {
      _plugins[index].enabled = !_plugins[index].enabled;
      await _savePlugins();
    }
  }

  /// 保存插件列表
  Future<void> _savePlugins() async {
    final file = await _getPluginFile();
    final json = _plugins.map((p) => p.toJson()).toList();
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(json));
  }

  /// 获取插件文件路径
  Future<File> _getPluginFile() async {
    final appDir = await getApplicationSupportDirectory();
    final dir = Directory('${appDir.path}/${AppConstants.pluginsDir}');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return File('${dir.path}/${AppConstants.pluginsFile}');
  }

  /// 创建默认示例插件
  List<Plugin> _createDefaultPlugins() {
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
        searchURL: 'https://api.bgm.tv/search/subject/{keyword}?type=2&max_results=25',
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
        searchURL: 'https://cj.ffzyapi.com/api.php/provide/vod/?ac=videolist&wd={keyword}',
        searchList: 'list',
        searchName: 'vod_name',
        searchResult: 'vod_id',
        chapterRoads: '',
        chapterResult: '',
        userAgent: AppConstants.defaultUserAgent,
        enabled: true,
      ),
      // 樱花动漫 CMS API
      Plugin(
        api: 'cms_yinhua',
        name: '樱花动漫',
        version: '1.0.0',
        baseUrl: 'https://www.yinhuadm.xyz',
        searchURL: 'https://www.yinhuadm.xyz/api.php/provide/vod/?ac=videolist&wd={keyword}',
        searchList: 'list',
        searchName: 'vod_name',
        searchResult: 'vod_id',
        chapterRoads: '',
        chapterResult: '',
        userAgent: AppConstants.defaultUserAgent,
        enabled: true,
      ),
    ];
  }

  // ============================================================
  // Jikan 排行榜 / 季度新番
  // ============================================================

  /// Jikan 排行榜
  Future<List<Map<String, dynamic>>> getJikanTopAnime({
    String? filter,
    String? type,
    int page = 1,
  }) async {
    return await JikanService().getTopAnime(
      filter: filter,
      type: type,
      page: page,
    );
  }

  /// Jikan 当前季度新番
  Future<List<Map<String, dynamic>>> getJikanSeasonNow() async {
    return await JikanService().getSeasonNow();
  }

  /// Jikan 下一季度
  Future<List<Map<String, dynamic>>> getJikanSeasonUpcoming() async {
    return await JikanService().getSeasonUpcoming();
  }

  /// Jikan 每周放送表
  Future<Map<String, List<Map<String, dynamic>>>> getJikanSchedule() async {
    return await JikanService().getFullWeekSchedule();
  }

  /// Jikan 推荐
  Future<List<Map<String, dynamic>>> getJikanRecommendations(int malId) async {
    return await JikanService().getAnimeRecommendations(malId);
  }

  /// Jikan 角色
  Future<List<Map<String, dynamic>>> getJikanCharacters(int malId) async {
    return await JikanService().getAnimeCharacters(malId);
  }
}
