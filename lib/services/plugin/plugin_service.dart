import '../../models/anime.dart';
import '../../models/playback/playback_source.dart';
import '../../models/plugin.dart';
import '../../utils/logger.dart';
import '../http/http_client.dart';
import '../jikan/jikan_service.dart';
import '../parser/xpath_parser.dart';
import '../playback/plugin_playback_episode_adapter.dart';
import '../playback/yinhua_playback_resolver.dart';
import 'plugin_api_client.dart';
import 'plugin_defaults.dart';
import 'plugin_repository.dart';

/// 插件门面：搜索编排、详情/集数分发与播放线路解析。
/// 文件持久化在 [PluginRepository]，默认注册表在 [PluginDefaults]，
/// 各后端 API 客户端在 [PluginApiClient]。
class PluginService {
  static final PluginService _instance = PluginService._();
  factory PluginService() => _instance;
  PluginService._() {
    _apiClient = PluginApiClient(pluginsProvider: () => _plugins);
    _yinhuaPlaybackResolver = YinhuaPlaybackResolver(
      loadHtml: (uri, headers) =>
          _http.getHtml(uri.toString(), headers: headers),
    );
  }

  final HttpClient _http = HttpClient();
  final PluginRepository _repository = PluginRepository();
  final PluginPlaybackEpisodeAdapter _playbackEpisodeAdapter =
      const PluginPlaybackEpisodeAdapter();
  late final PluginApiClient _apiClient;
  late final YinhuaPlaybackResolver _yinhuaPlaybackResolver;

  List<Plugin> _plugins = [];
  List<Plugin> get plugins => List.unmodifiable(_plugins);

  /// CMS 分类定义（保持既有引用兼容，数据源见 [PluginDefaults.cmsCategories]）
  static const Map<String, List<Map<String, dynamic>>> cmsCategories =
      PluginDefaults.cmsCategories;

  /// 初始化：加载插件并合并默认插件
  Future<void> init() async {
    _plugins = await _repository.load();
    final merged = PluginDefaults.mergeInto(_plugins);
    _plugins = merged.plugins;
    if (merged.changed) {
      await _repository.save(_plugins);
    }
  }

  /// 获取已启用的插件
  List<Plugin> getEnabledPlugins() {
    return _plugins.where((p) => p.enabled).toList();
  }

  static List<Plugin> enabledCatalogPlugins(Iterable<Plugin> plugins) {
    return plugins
        .where((plugin) => plugin.enabled && plugin.catalog != null)
        .toList(growable: false);
  }

  static Plugin? findEnabledCatalogPlugin(
    Iterable<Plugin> plugins,
    String providerId,
  ) {
    for (final plugin in plugins) {
      if (plugin.api == providerId &&
          plugin.enabled &&
          plugin.catalog != null) {
        return plugin;
      }
    }
    return null;
  }

  // ============================================================
  // 搜索编排
  // ============================================================

  /// 搜索所有已启用的插件
  Future<List<Anime>> searchAll(String keyword) async {
    final enabledPlugins = getEnabledPlugins();
    if (enabledPlugins.isEmpty) {
      Log.d('Plugin', '没有已启用的插件');
      return [];
    }

    final allResults = <Anime>[];

    // 并行搜索所有插件（每个插件最多10秒超时）
    final futures = enabledPlugins.map(
      (plugin) => _searchPlugin(plugin, keyword).timeout(
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
    final cmsPlugins = getEnabledPlugins()
        .where((p) => p.api.startsWith('cms_'))
        .toList();
    if (cmsPlugins.isEmpty) return [];

    final allResults = <Anime>[];
    final futures = cmsPlugins.map(
      (plugin) => _searchPlugin(plugin, keyword).timeout(
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
    final bangumiPlugin = _plugins
        .where((p) => p.api == 'bangumi' && p.enabled)
        .firstOrNull;
    if (bangumiPlugin == null) return [];
    return await _searchPlugin(bangumiPlugin, keyword).timeout(
      const Duration(seconds: 8),
      onTimeout: () => <Anime>[],
    );
  }

  /// 搜索单个插件
  Future<List<Anime>> _searchPlugin(Plugin plugin, String keyword) async {
    try {
      final searchUrl = plugin.searchURL
          .replaceAll('{keyword}', Uri.encodeComponent(keyword));

      Log.d('Plugin', '搜索 ${plugin.name}: $searchUrl');

      final headers = <String, String>{};
      if (plugin.userAgent.isNotEmpty) {
        headers['User-Agent'] = plugin.userAgent;
      }
      if (plugin.referer != null && plugin.referer!.isNotEmpty) {
        headers['Referer'] = plugin.referer!;
      }

      if (_apiClient.isJikanApi(plugin)) {
        return await JikanService().searchAnime(keyword);
      }
      if (_apiClient.isAnilistApi(plugin)) {
        return await _apiClient.searchAnilist(keyword);
      }
      if (_apiClient.isCmsApi(plugin)) {
        return await _apiClient.searchCms(plugin, keyword);
      }
      if (_apiClient.isJsonApi(plugin)) {
        return await _apiClient.searchJsonApi(plugin, searchUrl, headers);
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

      return results
          .map((r) => Anime(
                name: r.name ?? '',
                url: r.url ?? '',
                cover: r.cover,
                description: r.description,
                sourcePlugin: plugin.api,
              ))
          .where((a) => a.name.isNotEmpty && a.url.isNotEmpty)
          .toList();
    } catch (e) {
      Log.d('Plugin', '搜索 ${plugin.name} 失败: $e');
      return [];
    }
  }

  // ============================================================
  // 详情 / 集数
  // ============================================================

  /// 获取动漫详情
  Future<Map<String, dynamic>?> getDetail(Anime anime) async {
    if (anime.sourcePlugin == 'jikan') {
      final malId = JikanService.extractMalId(anime.url);
      if (malId == null) return null;
      return await JikanService().getAnimeDetails(malId);
    }
    if (anime.sourcePlugin == 'anilist') {
      return await _apiClient.getAnilistDetail(anime.url);
    }
    if (anime.sourcePlugin == 'bangumi') {
      return await _apiClient.getBangumiDetail(anime.url);
    }
    if (anime.sourcePlugin.startsWith('cms_')) {
      return await _apiClient.getCmsDetail(anime.url, anime.sourcePlugin);
    }
    return null;
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
      return List.generate(
        totalEps,
        (i) => Episode(
          name: '第${i + 1}话',
          url: '', // Jikan 不提供播放源，需配合 CMS 源使用
          index: i + 1,
        ),
      );
    }

    // Anilist 模式
    if (anime.sourcePlugin == 'anilist') {
      return await _apiClient.getAnilistEpisodes(anime.url);
    }

    // CMS 模式
    if (anime.sourcePlugin.startsWith('cms_')) {
      return await _apiClient.getCmsEpisodes(anime.url, anime.sourcePlugin);
    }

    // Bangumi API 模式
    if (anime.sourcePlugin == 'bangumi') {
      final detail = await getDetail(anime);
      if (detail == null) return [];
      final eps = detail['episodes'] as List? ?? [];
      return eps
          .map((ep) => Episode(
                name: ep['name'] ?? '第${ep['sort']}集',
                url: '${anime.url}/ep/${ep['sort']}',
                index: ep['sort'] ?? 0,
              ))
          .toList();
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

      return results
          .map((r) => Episode(
                name: r.name,
                url: r.url,
                index: r.index,
              ))
          .toList();
    } catch (e) {
      Log.d('Plugin', '获取章节失败: $e');
      return [];
    }
  }

  // ============================================================
  // 播放线路
  // ============================================================

  /// 获取保留线路信息的运行时章节列表。
  Future<List<PlaybackEpisode>> getPlaybackEpisodes(Anime anime) async {
    if (anime.sourcePlugin.startsWith('cms_')) {
      final cached = _apiClient.cachedCmsPlayback(anime.url);
      if (cached != null) return cached;
      try {
        final record = await _apiClient.fetchCmsRecord(anime);
        if (record == null) return [];
        return _apiClient.parseCmsPlaybackEpisodes(anime.url, record);
      } catch (e) {
        Log.d('Plugin', '获取 CMS 播放线路失败: $e');
        return [];
      }
    }

    final episodes = await getEpisodes(anime);
    return episodes
        .map(
          (episode) => PlaybackEpisode(
            name: episode.name,
            index: episode.index,
            sources: const [],
          ),
        )
        .toList(growable: false);
  }

  /// 按需解析指定章节的播放线路。
  Future<PlaybackEpisode> resolvePlaybackEpisode({
    required Anime anime,
    required Episode episode,
  }) async {
    if (anime.sourcePlugin.startsWith('cms_')) {
      final episodes = await getPlaybackEpisodes(anime);
      PlaybackEpisode? matched;
      for (final candidate in episodes) {
        if (candidate.index == episode.index) {
          matched = candidate;
          break;
        }
      }
      if (matched == null) {
        final normalizedName = _normalizeEpisodeName(episode.name);
        for (final candidate in episodes) {
          if (_normalizeEpisodeName(candidate.name) == normalizedName) {
            matched = candidate;
            break;
          }
        }
      }
      if (matched == null) {
        return PlaybackEpisode(
          name: episode.name,
          index: episode.index,
          sources: const [],
        );
      }
      if (anime.sourcePlugin == 'cms_yinhua') {
        final cmsId = anime.url.split(':').skip(1).join(':').trim();
        if (cmsId.isNotEmpty) {
          final plugin = _plugins.firstWhere(
            (candidate) => candidate.api == anime.sourcePlugin,
            orElse: () => _plugins.first,
          );
          return _yinhuaPlaybackResolver.resolveEpisode(
            baseUrl: Uri.parse(plugin.baseUrl),
            cmsId: cmsId,
            episode: matched,
          );
        }
      }
      return matched;
    }

    if (_plugins.isEmpty) {
      return PlaybackEpisode(
        name: episode.name,
        index: episode.index,
        sources: const [],
      );
    }
    final plugin = _plugins.firstWhere(
      (candidate) => candidate.api == anime.sourcePlugin,
      orElse: () => _plugins.first,
    );
    final urls = await getVideoUrls(episode.url, plugin);
    return _playbackEpisodeAdapter.fromHtml(
      episode: episode,
      plugin: plugin,
      urls: urls,
    );
  }

  String _normalizeEpisodeName(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'\s+'), '');
  }

  /// 获取视频源URL
  Future<List<String>> getVideoUrls(String episodeUrl, Plugin plugin) async {
    try {
      Log.d('Plugin', '获取视频源: $episodeUrl');

      // CMS 插件的视频源已经在详情中获取，直接返回
      if (_apiClient.isCmsApi(plugin)) {
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

  // ============================================================
  // CMS 列表（委托 API 客户端）
  // ============================================================

  Future<List<Map<String, dynamic>>> getCmsLatest({
    String? pluginApi,
    int page = 1,
  }) {
    return _apiClient.getCmsLatest(pluginApi: pluginApi, page: page);
  }

  Future<Map<String, dynamic>> getCmsByCategory({
    required String pluginApi,
    required int categoryId,
    int page = 1,
    String? sort,
  }) {
    return _apiClient.getCmsByCategory(
      pluginApi: pluginApi,
      categoryId: categoryId,
      page: page,
      sort: sort,
    );
  }

  Future<List<Map<String, dynamic>>> getCmsRanking({
    String? pluginApi,
    int pages = 3,
  }) {
    return _apiClient.getCmsRanking(pluginApi: pluginApi, pages: pages);
  }

  // ============================================================
  // 插件管理
  // ============================================================

  /// 添加插件
  Future<void> addPlugin(Plugin plugin) async {
    _plugins.add(plugin);
    await _repository.save(_plugins);
  }

  /// 删除插件
  Future<void> removePlugin(String api) async {
    _plugins.removeWhere((p) => p.api == api);
    await _repository.save(_plugins);
  }

  /// 切换插件启用状态
  Future<void> togglePlugin(String api) async {
    final index = _plugins.indexWhere((p) => p.api == api);
    if (index >= 0) {
      _plugins[index].enabled = !_plugins[index].enabled;
      await _repository.save(_plugins);
    }
  }

  /// 通过 Anilist 同义词查中文标题（详情页 CMS 搜源桥接用）。
  Future<String?> findChineseTitle(String keyword) {
    return _apiClient.findChineseTitle(keyword);
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
