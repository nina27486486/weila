import '../../models/anime.dart';
import '../../models/playback/playback_source.dart';
import '../../models/plugin.dart';
import '../../utils/constants.dart';
import '../../utils/logger.dart';
import '../http/http_client.dart';
import '../playback/cms_playback_source_parser.dart';
import 'plugin_defaults.dart';

/// 单条 CMS vod 记录及其来源插件。
class CmsVodRecord {
  const CmsVodRecord({
    required this.plugin,
    required this.item,
  });

  final Plugin plugin;
  final Map<String, dynamic> item;
}

/// 插件后端 API 客户端：类型嗅探、各元数据/CMS 源的搜索与详情、
/// CMS 列表与播放线路解析。插件列表通过 provider 回调注入，
/// 使其独立于 PluginService 的可变状态、可直接单测。
class PluginApiClient {
  PluginApiClient({
    required List<Plugin> Function() pluginsProvider,
    HttpClient? http,
    CmsPlaybackSourceParser? cmsPlaybackParser,
  })  : _pluginsProvider = pluginsProvider,
        _http = http ?? HttpClient(),
        _cmsPlaybackParser = cmsPlaybackParser ?? const CmsPlaybackSourceParser();

  final List<Plugin> Function() _pluginsProvider;
  final HttpClient _http;
  final CmsPlaybackSourceParser _cmsPlaybackParser;
  final Map<String, List<PlaybackEpisode>> _cmsPlaybackCache = {};

  List<Plugin> get _plugins => _pluginsProvider();

  Plugin _pluginFor(String api) {
    return _plugins.firstWhere(
      (candidate) => candidate.api == api,
      orElse: () => _plugins.first,
    );
  }

  // ============================================================
  // API 类型嗅探
  // ============================================================

  bool isJsonApi(Plugin plugin) {
    return plugin.baseUrl.contains('api.bgm.tv') ||
        plugin.searchList == 'list' ||
        plugin.searchURL.contains('api.');
  }

  bool isAnilistApi(Plugin plugin) {
    return plugin.api == 'anilist' || plugin.baseUrl.contains('anilist.co');
  }

  bool isCmsApi(Plugin plugin) {
    return plugin.api.startsWith('cms_') ||
        plugin.searchURL.contains('api.php/provide/vod');
  }

  bool isJikanApi(Plugin plugin) {
    return plugin.api == 'jikan' || plugin.baseUrl.contains('jikan.moe');
  }

  // ============================================================
  // JSON / Bangumi 搜索
  // ============================================================

  Future<List<Anime>> searchJsonApi(
    Plugin plugin,
    String url,
    Map<String, String> headers,
  ) async {
    Log.d('Plugin', 'JSON API 请求: $url');
    final data = await _http.getJson(url, headers: headers);
    final results = <Anime>[];

    if (data is Map<String, dynamic>) {
      if (data.containsKey('list')) {
        // Bangumi API 格式
        final list = data['list'] as List? ?? [];
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

    return results.where((a) => a.name.isNotEmpty).toList();
  }

  // ============================================================
  // CMS 采集站 API
  // ============================================================

  Future<List<Anime>> searchCms(Plugin plugin, String keyword) async {
    try {
      final url = plugin.searchURL
          .replaceAll('{keyword}', Uri.encodeComponent(keyword));
      Log.d('CMS', '搜索 ${plugin.name}: $url');
      final headers = <String, String>{'Accept': 'application/json'};
      if (plugin.userAgent.isNotEmpty) headers['User-Agent'] = plugin.userAgent;
      final data = await _http.getJson(url, headers: headers);
      if (data is! Map<String, dynamic>) return [];
      final list = data['list'] as List? ?? [];

      // 获取该源的动漫分类ID，用于过滤非动漫内容
      final animeTypeIds = (PluginDefaults.cmsCategories[plugin.api] ?? [])
          .map((c) => c['id'] as int)
          .toSet();

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

  Future<CmsVodRecord?> fetchCmsRecord(Anime anime) async {
    final parts = anime.url.split(':');
    if (parts.length < 2 || _plugins.isEmpty) return null;
    final cmsId = parts[1];
    final plugin = _pluginFor(anime.sourcePlugin);
    final url = '${plugin.baseUrl}/api.php/provide/vod/?ac=detail&ids=$cmsId';
    Log.d('CMS', '获取详情: $url');
    final data = await _http.getJson(
      url,
      headers: {'User-Agent': plugin.userAgent},
    );
    if (data is! Map<String, dynamic>) return null;
    final list = data['list'] as List? ?? [];
    if (list.isEmpty || list.first is! Map) return null;
    return CmsVodRecord(
      plugin: plugin,
      item: Map<String, dynamic>.from(list.first as Map),
    );
  }

  List<PlaybackEpisode>? cachedCmsPlayback(String animeUrl) {
    return _cmsPlaybackCache[animeUrl];
  }

  List<PlaybackEpisode> parseCmsPlaybackEpisodes(
    String animeUrl,
    CmsVodRecord record,
  ) {
    final cached = _cmsPlaybackCache[animeUrl];
    if (cached != null) return cached;
    final headers = <String, String>{
      if (record.plugin.userAgent.trim().isNotEmpty)
        'User-Agent': record.plugin.userAgent.trim(),
      if (record.plugin.referer?.trim().isNotEmpty == true)
        'Referer': record.plugin.referer!.trim(),
    };
    final episodes = _cmsPlaybackParser.parse(
      playFrom: record.item['vod_play_from']?.toString() ?? '',
      playUrl: record.item['vod_play_url']?.toString() ?? '',
      headers: headers,
    );
    final stable = List<PlaybackEpisode>.unmodifiable(episodes);
    _cmsPlaybackCache[animeUrl] = stable;
    return stable;
  }

  Future<Map<String, dynamic>?> getCmsDetail(
    String animeUrl,
    String sourcePlugin,
  ) async {
    try {
      final anime = Anime(
        name: '',
        url: animeUrl,
        sourcePlugin: sourcePlugin,
      );
      final record = await fetchCmsRecord(anime);
      if (record == null) return null;
      final plugin = record.plugin;
      final item = record.item;
      final playbackEpisodes = parseCmsPlaybackEpisodes(animeUrl, record);
      final episodes = <Map<String, dynamic>>[];
      for (final episode in playbackEpisodes) {
        final resolved = const PlaybackSelection.auto().resolve(episode.sources);
        if (resolved == null) continue;
        episodes.add({
          'sort': episode.index,
          'name': episode.name,
          'url': resolved.variant.url,
        });
      }
      final tags = (item['vod_class']?.toString() ?? '')
          .split(',')
          .where((t) => t.trim().isNotEmpty)
          .toList();
      return {
        'name': item['vod_name']?.toString() ?? '',
        'name_cn': item['vod_name']?.toString() ?? '',
        'name_ja': item['vod_sub']?.toString() ?? '',
        'summary': stripHtml(item['vod_content']?.toString() ??
            item['vod_blurb']?.toString() ??
            ''),
        'cover': fixCoverUrl(item['vod_pic']?.toString(), plugin.baseUrl),
        'rating': double.tryParse(item['vod_score']?.toString() ?? ''),
        'tags': tags,
        'date': item['vod_pubdate']?.toString() ??
            item['vod_year']?.toString() ??
            '',
        'platform': item['vod_area']?.toString() ?? '',
        'total_episodes':
            int.tryParse(item['vod_total']?.toString() ?? '') ?? episodes.length,
        'episodes': episodes,
        'status': item['vod_remarks']?.toString(),
      };
    } catch (e) {
      Log.e('CMS', '获取详情失败', e);
      return null;
    }
  }

  Future<List<Episode>> getCmsEpisodes(
    String animeUrl,
    String sourcePlugin,
  ) async {
    final detail = await getCmsDetail(animeUrl, sourcePlugin);
    if (detail == null) return [];
    final eps = detail['episodes'] as List? ?? [];
    return eps
        .map((ep) => Episode(
              name: ep['name'] ?? '第${ep['sort']}集',
              url: ep['url'] ?? '',
              index: ep['sort'] ?? 0,
            ))
        .toList();
  }

  Future<List<Map<String, dynamic>>> getCmsLatest({
    String? pluginApi,
    int page = 1,
  }) async {
    final api = pluginApi ?? 'cms_yinhua';
    if (_plugins.isEmpty) return [];
    final plugin = _plugins.firstWhere(
      (p) => p.api == api,
      orElse: () => _plugins.firstWhere(
        (p) => p.api.startsWith('cms_'),
        orElse: () => _plugins.first,
      ),
    );
    try {
      final catId = api == 'cms_ffzy' ? '30' : '10';
      final url =
          '${plugin.baseUrl}/api.php/provide/vod/?ac=videolist&t=$catId&pg=$page';
      Log.d('CMS', '首页数据: $url');
      final headers = <String, String>{'Accept': 'application/json'};
      if (plugin.userAgent.isNotEmpty) headers['User-Agent'] = plugin.userAgent;
      final data = await _http.getJson(url, headers: headers);
      if (data is! Map<String, dynamic>) return [];
      final list = data['list'] as List? ?? [];
      return list.whereType<Map<String, dynamic>>().map((item) {
        return {
          'id': item['vod_id']?.toString() ?? '',
          'name': item['vod_name']?.toString() ?? '',
          'cover': fixCoverUrl(item['vod_pic']?.toString(), plugin.baseUrl),
          'score': double.tryParse(item['vod_score']?.toString() ?? ''),
          'status': item['vod_remarks']?.toString() ?? '',
          'genres': (item['vod_class']?.toString() ?? '')
              .split(',')
              .where((g) => g.trim().isNotEmpty)
              .take(3)
              .toList(),
          'year': item['vod_year']?.toString() ?? '',
          'area': item['vod_area']?.toString() ?? '',
          'vod_time': item['vod_time']?.toString() ?? '',
          'url': '${plugin.api}:${item['vod_id']}',
          'sourcePlugin': plugin.api,
        };
      }).toList();
    } catch (e) {
      Log.e('CMS', '首页数据获取失败', e);
      return [];
    }
  }

  Future<Map<String, dynamic>> getCmsByCategory({
    required String pluginApi,
    required int categoryId,
    int page = 1,
    String? sort, // hits/time/score
  }) async {
    const empty = <String, dynamic>{'list': <Map<String, dynamic>>[], 'total': 0, 'pages': 0};
    if (_plugins.isEmpty) return empty;
    final plugin = _plugins.firstWhere(
      (p) => p.api == pluginApi,
      orElse: () => _plugins.firstWhere(
        (p) => p.api.startsWith('cms_'),
        orElse: () => _plugins.first,
      ),
    );
    try {
      var url =
          '${plugin.baseUrl}/api.php/provide/vod/?ac=videolist&t=$categoryId&pg=$page';
      if (sort != null) url += '&sort=$sort';
      Log.d('CMS', '分类列表: $url');
      final headers = <String, String>{'Accept': 'application/json'};
      if (plugin.userAgent.isNotEmpty) headers['User-Agent'] = plugin.userAgent;
      final data = await _http.getJson(url, headers: headers);
      if (data is! Map<String, dynamic>) return empty;
      final list = data['list'] as List? ?? [];
      final total = data['total'] as int? ?? 0;
      final pages = data['pagecount'] as int? ?? 0;
      return {
        'list': list.whereType<Map<String, dynamic>>().map((item) {
          return {
            'id': item['vod_id']?.toString() ?? '',
            'name': item['vod_name']?.toString() ?? '',
            'cover': fixCoverUrl(item['vod_pic']?.toString(), plugin.baseUrl),
            'score': double.tryParse(item['vod_score']?.toString() ?? ''),
            'status': item['vod_remarks']?.toString() ?? '',
            'genres': (item['vod_class']?.toString() ?? '')
                .split(',')
                .where((g) => g.trim().isNotEmpty)
                .take(3)
                .toList(),
            'year': item['vod_year']?.toString() ?? '',
            'area': item['vod_area']?.toString() ?? '',
            'url': '${plugin.api}:${item['vod_id']}',
            'sourcePlugin': plugin.api,
          };
        }).toList(),
        'total': total,
        'pages': pages,
      };
    } catch (e) {
      Log.e('CMS', '分类列表获取失败', e);
      return empty;
    }
  }

  Future<List<Map<String, dynamic>>> getCmsRanking({
    String? pluginApi,
    int pages = 3,
  }) async {
    final api = pluginApi ?? 'cms_yinhua';
    final categories = PluginDefaults.cmsCategories[api] ?? [];
    if (categories.isEmpty) return [];
    final catId = categories.first['id'] as int;

    final allItems = <Map<String, dynamic>>[];
    for (int pg = 1; pg <= pages; pg++) {
      final result =
          await getCmsByCategory(pluginApi: api, categoryId: catId, page: pg);
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

  // ============================================================
  // Anilist GraphQL API
  // ============================================================

  static const _anilistEndpoint = 'https://graphql.anilist.co';

  Future<List<Anime>> searchAnilist(String keyword) async {
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
        final name =
            title['native']?.toString() ?? title['romaji']?.toString() ?? '';
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

  Future<Map<String, dynamic>?> getAnilistDetail(String animeUrl) async {
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
        'rating': media['averageScore'] != null
            ? (media['averageScore'] as int) / 10.0
            : null,
        'tags': (media['genres'] as List?)?.cast<String>() ?? [],
        'status': media['status']?.toString(),
        'total_episodes': media['episodes'],
      };
    } catch (e) {
      Log.e('Anilist', '获取详情失败', e);
      return null;
    }
  }

  Future<List<Episode>> getAnilistEpisodes(String animeUrl) async {
    final detail = await getAnilistDetail(animeUrl);
    if (detail == null) return [];
    final totalEps = detail['total_episodes'] as int? ?? 12;
    return List.generate(
      totalEps,
      (i) => Episode(
        name: '第${i + 1}集',
        url: '',
        index: i + 1,
      ),
    );
  }

  // ============================================================
  // Bangumi 详情
  // ============================================================

  Future<Map<String, dynamic>?> getBangumiDetail(String subjectUrl) async {
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
            ?.where((ep) => ep['type'] == 0) // 只要正片
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

  // ============================================================
  // 工具
  // ============================================================

  /// 修复封面URL：相对路径拼上baseUrl
  static String? fixCoverUrl(String? url, String baseUrl) {
    if (url == null || url.isEmpty || url == 'null') return null;
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    if (url.startsWith('//')) return 'https:$url';
    // 相对路径：拼上baseUrl
    return '$baseUrl/${url.startsWith('/') ? url.substring(1) : url}';
  }

  static String stripHtml(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&amp;', '&')
        .trim();
  }
}
