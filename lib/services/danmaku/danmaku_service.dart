import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import '../../models/danmaku_item.dart';
import '../../utils/constants.dart';
import '../../utils/logger.dart';

/// 弹幕服务 — 接入弹弹play开放API
class DanmakuService {
  static final DanmakuService _instance = DanmakuService._();
  factory DanmakuService() => _instance;
  DanmakuService._();

  static const _baseUrl = 'https://api.dandanplay.net';
  late final Dio _dio;

  /// API 认证信息
  String? _appId;
  String? _appSecret;

  /// 已缓存的弹幕（episodeId -> 弹幕列表）
  final Map<String, List<DanmakuItem>> _cache = {};

  void init() {
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      headers: {
        'User-Agent': 'Weila/${AppConstants.appVersion} (Desktop Anime Player)',
        'Accept': 'application/json',
      },
    ));
    // 禁用代理，直连弹弹play
    _dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () {
        final client = HttpClient();
        client.findProxy = (uri) => 'DIRECT';
        return client;
      },
    );
  }

  /// 设置 API 认证信息
  void setCredentials(String appId, String appSecret) {
    _appId = appId;
    _appSecret = appSecret;
  }

  /// 是否已配置 API Key
  bool get hasCredentials => _appId != null && _appSecret != null;

  /// 获取带认证头的请求头
  Map<String, String> get _authHeaders {
    final headers = <String, String>{
      'Accept': 'application/json',
    };
    if (_appId != null) headers['X-App-Id'] = _appId!;
    if (_appSecret != null) headers['X-App-Secret'] = _appSecret!;
    return headers;
  }

  /// 搜索番剧匹配弹幕
  /// 返回匹配的 animeId 和 episodeId 列表
  Future<List<Map<String, dynamic>>> searchEpisode(
      String animeName, int episodeNum) async {
    if (!hasCredentials) {
      Log.d('Danmaku', '未配置弹弹play API Key，跳过');
      return [];
    }
    try {
      Log.d('Danmaku', '搜索匹配: $animeName 第$episodeNum集');

      final response = await _dio.get(
        '$_baseUrl/api/v2/search/episodes',
        queryParameters: {'anime': animeName, 'episode': ''},
        options: Options(headers: _authHeaders),
      );

      if (response.data is! Map<String, dynamic>) return [];
      final data = response.data as Map<String, dynamic>;
      final animes = data['animes'] as List? ?? [];

      final results = <Map<String, dynamic>>[];
      for (final anime in animes) {
        if (anime is! Map<String, dynamic>) continue;
        final episodes = anime['episodes'] as List? ?? [];
        for (final ep in episodes) {
          if (ep is! Map<String, dynamic>) continue;
          final epTitle = ep['episodeTitle']?.toString() ?? '';
          // 匹配集数：标题包含集数号，或者精确匹配
          if (epTitle.contains('$episodeNum') ||
              epTitle.contains('第$episodeNum')) {
            results.add({
              'animeId': anime['animeId'],
              'episodeId': ep['episodeId'],
              'title': anime['animeTitle']?.toString() ?? '',
              'episodeTitle': epTitle,
            });
          }
        }
      }

      Log.d('Danmaku', '匹配到 ${results.length} 个结果');
      return results;
    } catch (e) {
      Log.e('Danmaku', '搜索失败', e);
      return [];
    }
  }

  /// 获取弹幕列表
  Future<List<DanmakuItem>> getDanmaku(int episodeId) async {
    final cacheKey = '$episodeId';

    // 检查缓存
    if (_cache.containsKey(cacheKey)) {
      Log.d('Danmaku', '命中缓存: episodeId=$episodeId');
      return _cache[cacheKey]!;
    }

    try {
      Log.d('Danmaku', '获取弹幕: episodeId=$episodeId');

      final response = await _dio.get(
        '$_baseUrl/api/v2/comment/$episodeId',
        queryParameters: {'withRelated': true},
        options: Options(headers: _authHeaders),
      );

      if (response.data is! Map<String, dynamic>) return [];
      final data = response.data as Map<String, dynamic>;
      final comments = data['comments'] as List? ?? [];

      final danmakuList = <DanmakuItem>[];
      for (final comment in comments) {
        if (comment is! Map<String, dynamic>) continue;
        final p = comment['p']?.toString() ?? '';
        final m = comment['m']?.toString() ?? '';
        if (p.isNotEmpty && m.isNotEmpty) {
          danmakuList.add(DanmakuItem.fromDandanPlay(p, m));
        }
      }

      // 按时间排序
      danmakuList.sort((a, b) => a.time.compareTo(b.time));

      // 缓存
      _cache[cacheKey] = danmakuList;

      Log.d('Danmaku', '获取 ${danmakuList.length} 条弹幕');
      return danmakuList;
    } catch (e) {
      Log.e('Danmaku', '获取弹幕失败', e);
      return [];
    }
  }

  /// 智能匹配并获取弹幕
  /// 先搜索番剧，找到匹配的 episodeId，再获取弹幕
  Future<List<DanmakuItem>> fetchDanmaku(
      String animeName, int episodeNum) async {
    final episodes = await searchEpisode(animeName, episodeNum);
    if (episodes.isEmpty) {
      Log.d('Danmaku', '未找到匹配: $animeName 第$episodeNum集');
      return [];
    }

    // 取第一个匹配结果
    final episodeId = episodes.first['episodeId'] as int;
    return await getDanmaku(episodeId);
  }

  /// 清除缓存
  void clearCache() {
    _cache.clear();
  }

  /// 获取缓存大小
  int get cacheSize => _cache.length;
}
