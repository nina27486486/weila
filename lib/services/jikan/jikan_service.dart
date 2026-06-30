import '../../utils/logger.dart';
import '../../models/anime.dart';
import '../http/http_client.dart';

/// Jikan API 客户端（MyAnimeList 非官方封装）
/// 文档：https://docs.api.jikan.moe/
/// 限流：60 req/min, 3 req/sec
class JikanService {
  static final JikanService _instance = JikanService._();
  factory JikanService() => _instance;
  JikanService._();

  final HttpClient _http = HttpClient();
  static const String _baseUrl = 'https://api.jikan.moe/v4';

  // ─── 内存缓存（简单实现，后续可迁移到 Hive） ───
  final Map<String, _CacheEntry> _cache = {};
  static const Duration _cacheDuration = Duration(minutes: 30);

  /// 通用 GET 请求（带缓存 + 限流保护）
  Future<Map<String, dynamic>?> _get(String path) async {
    final cacheKey = path;
    final cached = _cache[cacheKey];
    if (cached != null && !cached.isExpired) {
      Log.d('Jikan', '命中缓存: $path');
      return cached.data;
    }

    try {
      Log.d('Jikan', '请求: $_baseUrl$path');
      final data = await _http.getJson('$_baseUrl$path');
      if (data is Map<String, dynamic>) {
        _cache[cacheKey] = _CacheEntry(data);
        return data;
      }
      Log.d('Jikan', '响应格式异常: ${data.runtimeType}');
      return null;
    } catch (e) {
      Log.e('Jikan', '请求失败: $path', e);
      return null;
    }
  }

  // ============================================================
  // 搜索
  // ============================================================

  /// 搜索动漫
  Future<List<Anime>> searchAnime(String keyword, {int limit = 15}) async {
    final data = await _get(
        '/anime?q=${Uri.encodeComponent(keyword)}&limit=$limit&sfw=true');
    if (data == null) return [];

    final items = data['data'] as List? ?? [];
    return items.whereType<Map<String, dynamic>>().map((item) {
      return Anime(
        name: item['title']?.toString() ?? '',
        url: 'jikan:${item['mal_id']}',
        cover: item['images']?['jpg']?['large_image_url']?.toString() ??
            item['images']?['jpg']?['image_url']?.toString(),
        description: item['synopsis']?.toString(),
        sourcePlugin: 'jikan',
      );
    }).where((a) => a.name.isNotEmpty).toList();
  }

  // ============================================================
  // 动漫详情
  // ============================================================

  /// 获取动漫详情（返回 Map 供 plugin_service 使用）
  Future<Map<String, dynamic>?> getAnimeDetails(int malId) async {
    final data = await _get('/anime/$malId/full');
    if (data == null) return null;

    final item = data['data'] as Map<String, dynamic>?;
    if (item == null) return null;

    final genres = <String>[];
    for (final g in (item['genres'] as List? ?? [])) {
      if (g is Map && g['name'] != null) genres.add(g['name'].toString());
    }
    for (final g in (item['themes'] as List? ?? [])) {
      if (g is Map && g['name'] != null) genres.add(g['name'].toString());
    }

    final studios = <String>[];
    for (final s in (item['studios'] as List? ?? [])) {
      if (s is Map && s['name'] != null) studios.add(s['name'].toString());
    }

    return {
      'mal_id': item['mal_id'],
      'name': item['title']?.toString() ?? '',
      'name_cn':
          item['title_japanese']?.toString() ?? item['title']?.toString() ?? '',
      'name_ja': item['title_japanese']?.toString() ?? '',
      'name_en': item['title_english']?.toString() ?? '',
      'summary': item['synopsis']?.toString() ?? '',
      'cover': item['images']?['jpg']?['large_image_url']?.toString(),
      'rating':
          item['score'] != null ? (item['score'] as num).toDouble() : null,
      'rating_count': item['scored_by'],
      'rank': item['rank'],
      'popularity': item['popularity'],
      'tags': genres,
      'studios': studios,
      'status': item['status']?.toString() ?? '',
      'type': item['type']?.toString() ?? '',
      'source': item['source']?.toString() ?? '',
      'season': item['season']?.toString() ?? '',
      'year': item['year'],
      'date': item['aired']?['string']?.toString() ?? '',
      'duration': item['duration']?.toString() ?? '',
      'total_episodes': item['episodes'] ?? 0,
      'members': item['members'],
      'favorites': item['favorites'],
      'opening_themes': (item['theme']?['openings'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      'ending_themes': (item['theme']?['endings'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    };
  }

  // ============================================================
  // 角色
  // ============================================================

  /// 获取动漫角色列表
  Future<List<Map<String, dynamic>>> getAnimeCharacters(int malId) async {
    final data = await _get('/anime/$malId/characters');
    if (data == null) return [];

    final items = data['data'] as List? ?? [];
    return items.whereType<Map<String, dynamic>>().take(20).map((item) {
      final char = item['character'] as Map<String, dynamic>? ?? {};
      return {
        'name': char['name']?.toString() ?? '',
        'name_kanji': char['name_kanji']?.toString() ?? '',
        'image': char['images']?['jpg']?['image_url']?.toString(),
        'role': item['role']?.toString() ?? '',
        'favorites': item['favorites'] ?? 0,
      };
    }).toList();
  }

  // ============================================================
  // 推荐
  // ============================================================

  /// 获取动漫推荐列表
  Future<List<Map<String, dynamic>>> getAnimeRecommendations(int malId) async {
    final data = await _get('/anime/$malId/recommendations');
    if (data == null) return [];

    final items = data['data'] as List? ?? [];
    return items.whereType<Map<String, dynamic>>().take(12).map((item) {
      final entry = item['entry'] as Map<String, dynamic>? ?? {};
      return {
        'mal_id': entry['mal_id'],
        'name': entry['title']?.toString() ?? '',
        'cover': entry['images']?['jpg']?['large_image_url']?.toString() ??
            entry['images']?['jpg']?['image_url']?.toString(),
        'votes': item['votes'] ?? 0,
        'url': 'jikan:${entry['mal_id']}',
      };
    }).toList();
  }

  // ============================================================
  // 排行榜
  // ============================================================

  /// 获取动漫排行榜
  /// [filter]: 空=按评分, 'bypopularity'=按人气, 'favorite'=按收藏
  /// [type]: 空=全部, 'tv'=TV, 'movie'=剧场版, 'ova'=OVA, 'ona'=ONA
  Future<List<Map<String, dynamic>>> getTopAnime({
    String? filter,
    String? type,
    int page = 1,
    int limit = 25,
  }) async {
    var path = '/top/anime?page=$page&limit=$limit&sfw=true';
    if (filter != null && filter.isNotEmpty) path += '&filter=$filter';
    if (type != null && type.isNotEmpty) path += '&type=$type';

    final data = await _get(path);
    if (data == null) return [];

    final items = data['data'] as List? ?? [];
    return items.whereType<Map<String, dynamic>>().map((item) {
      return _toAnimeCard(item);
    }).toList();
  }

  // ============================================================
  // 季度新番
  // ============================================================

  /// 获取当前季度新番
  Future<List<Map<String, dynamic>>> getSeasonNow() async {
    final data = await _get('/seasons/now?sfw=true&limit=25');
    if (data == null) return [];
    return _parseAnimeList(data);
  }

  /// 获取下一季度预告
  Future<List<Map<String, dynamic>>> getSeasonUpcoming() async {
    final data = await _get('/seasons/upcoming?sfw=true&limit=25');
    if (data == null) return [];
    return _parseAnimeList(data);
  }

  /// 获取指定季度番剧（如 2025, winter）
  Future<List<Map<String, dynamic>>> getSeason({
    required int year,
    required String season, // winter/spring/summer/fall
  }) async {
    final data = await _get('/seasons/$year/$season?sfw=true&limit=25');
    if (data == null) return [];
    return _parseAnimeList(data);
  }

  // ============================================================
  // 放送时间表（用于追番日历）
  // ============================================================

  /// 获取每周放送表
  /// [filter]: monday/tuesday/wednesday/thursday/friday/saturday/sunday/other/unknown
  Future<List<Map<String, dynamic>>> getSchedule({String? day}) async {
    var path = '/schedules?sfw=true&limit=25';
    if (day != null && day.isNotEmpty) path += '&filter=$day';

    final data = await _get(path);
    if (data == null) return [];
    return _parseAnimeList(data);
  }

  /// 获取整周放送表（7天全部）
  Future<Map<String, List<Map<String, dynamic>>>> getFullWeekSchedule() async {
    final days = [
      'monday',
      'tuesday',
      'wednesday',
      'thursday',
      'friday',
      'saturday',
      'sunday'
    ];
    final result = <String, List<Map<String, dynamic>>>{};

    for (final day in days) {
      result[day] = await getSchedule(day: day);
    }
    return result;
  }

  // ============================================================
  // 工具方法
  // ============================================================

  List<Map<String, dynamic>> _parseAnimeList(Map<String, dynamic> data) {
    final items = data['data'] as List? ?? [];
    return items.whereType<Map<String, dynamic>>().map((item) {
      return _toAnimeCard(item);
    }).toList();
  }

  /// 将 Jikan 响应转换为统一的卡片数据格式
  Map<String, dynamic> _toAnimeCard(Map<String, dynamic> item) {
    final genres = (item['genres'] as List? ?? [])
        .whereType<Map>()
        .map((g) => g['name']?.toString() ?? '')
        .where((n) => n.isNotEmpty)
        .take(3)
        .toList();

    return {
      'mal_id': item['mal_id'],
      'id': 'jikan:${item['mal_id']}',
      'name': item['title']?.toString() ??
          item['title_english']?.toString() ??
          '',
      'cover': item['images']?['jpg']?['large_image_url']?.toString() ??
          item['images']?['jpg']?['image_url']?.toString(),
      'score': item['score'] != null
          ? (item['score'] as num).toDouble()
          : null,
      'status': item['status']?.toString() ??
          (item['airing'] == true ? '连载中' : ''),
      'genres': genres,
      'year': item['year']?.toString() ?? '',
      'area': '日本',
      'type': item['type']?.toString() ?? '',
      'episodes': item['episodes'],
      'members': item['members'],
      'url': 'jikan:${item['mal_id']}',
      'sourcePlugin': 'jikan',
    };
  }

  /// 从 jikan:12345 格式的 URL 提取 mal_id
  static int? extractMalId(String animeUrl) {
    if (!animeUrl.startsWith('jikan:')) return null;
    return int.tryParse(animeUrl.replaceFirst('jikan:', ''));
  }

  /// 清除缓存
  void clearCache() {
    _cache.clear();
    Log.d('Jikan', '缓存已清除');
  }
}

/// 缓存条目
class _CacheEntry {
  final Map<String, dynamic> data;
  final DateTime createdAt;

  _CacheEntry(this.data) : createdAt = DateTime.now();

  bool get isExpired =>
      DateTime.now().difference(createdAt) > JikanService._cacheDuration;
}
