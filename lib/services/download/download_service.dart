import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import '../../models/download_item.dart';
import '../../utils/constants.dart';
import '../../utils/logger.dart';

/// 下载服务 — 管理 M3U8 视频流下载
/// 单例模式，最大并发 3 个下载任务
class DownloadService {
  static final DownloadService _instance = DownloadService._();
  factory DownloadService() => _instance;
  DownloadService._();

  static const int _maxConcurrent = 3;

  late Dio _dio;
  late Directory _downloadDir;
  late Box<DownloadItem> _downloadBox;

  /// episodeUrl -> CancelToken（用于暂停/取消）
  final Map<String, CancelToken> _activeTokens = {};

  /// episodeUrl -> DownloadItem（内存中的活跃任务）
  final Map<String, DownloadItem> _activeTasks = {};

  bool _initialized = false;

  // ============================================================
  // 初始化
  // ============================================================

  Future<void> init() async {
    if (_initialized) return;

    // 初始化 Dio（禁用代理，CDN 直连）
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 60),
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
            '(KHTML, like Gecko) Chrome/136.0.0.0 Safari/537.36',
        'Accept': '*/*',
      },
    ));
    // 禁用系统代理（CDN 直连，避免代理未开导致连接失败）
    _dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () {
        final client = HttpClient();
        client.findProxy = (uri) => 'DIRECT';
        return client;
      },
    );

    // 获取应用支持目录 & 创建 downloads 子目录
    final appDir = await getApplicationSupportDirectory();
    _downloadDir = Directory('${appDir.path}/downloads');
    if (!await _downloadDir.exists()) {
      await _downloadDir.create(recursive: true);
    }

    // 打开 Hive box（使用 StorageService 已注册的 adapter）
    _downloadBox = await Hive.openBox<DownloadItem>(AppConstants.boxDownload);

    // 恢复未完成的任务（状态为等待中或下载中的，重置为等待中）
    for (final item in _downloadBox.values) {
      if (item.status == 1 || item.status == 0) {
        item.status = 0; // 重置为等待中
        await item.save();
      }
      _activeTasks[item.episodeUrl] = item;
    }

    _initialized = true;
    Log.d('Download', '初始化完成，下载目录: ${_downloadDir.path}');

    // 启动等待中的下载
    _processQueue();
  }

  void _ensureInitialized() {
    if (!_initialized) {
      throw StateError('DownloadService 未初始化，请先调用 init()');
    }
  }

  // ============================================================
  // 公共 API
  // ============================================================

  /// 获取所有下载任务
  List<DownloadItem> getAllDownloads() {
    _ensureInitialized();
    return _downloadBox.values.toList();
  }

  /// 添加下载任务到队列
  Future<void> addDownload(DownloadItem item) async {
    _ensureInitialized();

    // 始终用 CDN 域名推导正确的 CMS 站点 Referer（覆盖调用方设置的）
    item.referer = _getRefererForCdn(item.m3u8Url);

    // 去重：如果已经在下载或已完成，跳过
    if (_activeTasks.containsKey(item.episodeUrl)) {
      Log.d('Download', '任务已存在: ${item.episodeName}');
      return;
    }

    // 检查是否已下载完成（本地文件存在）
    if (await isDownloaded(item.episodeUrl)) {
      Log.d('Download', '已下载完成: ${item.episodeName}');
      return;
    }

    item.status = 0; // 等待中
    item.progress = 0.0;
    await _downloadBox.put(item.episodeUrl, item);
    _activeTasks[item.episodeUrl] = item;

    Log.d('Download', '添加下载: ${item.animeName} - ${item.episodeName}');
    _processQueue();
  }

  /// 暂停下载
  Future<void> pauseDownload(String episodeUrl) async {
    _ensureInitialized();
    final item = _activeTasks[episodeUrl];
    if (item == null) return;

    // 取消活跃的网络请求
    _activeTokens[episodeUrl]?.cancel('用户暂停');
    _activeTokens.remove(episodeUrl);

    item.status = 3; // 已暂停
    await item.save();

    Log.d('Download', '已暂停: ${item.episodeName}');
    _processQueue();
  }

  /// 恢复下载
  Future<void> resumeDownload(String episodeUrl) async {
    _ensureInitialized();
    final item = _activeTasks[episodeUrl];
    if (item == null) return;
    if (item.status != 3) return; // 只有暂停状态才能恢复

    item.status = 0; // 重置为等待中
    await item.save();

    Log.d('Download', '恢复下载: ${item.episodeName}');
    _processQueue();
  }

  /// 取消下载并删除部分文件
  Future<void> cancelDownload(String episodeUrl) async {
    _ensureInitialized();
    final item = _activeTasks[episodeUrl];
    if (item == null) return;

    // 取消网络请求
    _activeTokens[episodeUrl]?.cancel('用户取消');
    _activeTokens.remove(episodeUrl);

    // 删除临时文件和最终文件
    await _cleanupFiles(item);

    // 从队列中移除
    await _downloadBox.delete(episodeUrl);
    _activeTasks.remove(episodeUrl);

    Log.d('Download', '已取消: ${item.episodeName}');
    _processQueue();
  }

  /// 重试失败的下载
  Future<void> retryDownload(String episodeUrl) async {
    _ensureInitialized();
    final item = _activeTasks[episodeUrl];
    if (item == null) return;
    if (item.status != 4) return; // 只有失败状态才能重试

    item.status = 0;
    item.progress = 0.0;
    item.downloadedSegments = 0;
    await item.save();

    Log.d('Download', '重试下载: ${item.episodeName}');
    _processQueue();
  }

  /// 获取下载文件路径
  String getDownloadPath(String animeName, String episodeName) {
    final safeAnime = _sanitizeFileName(animeName);
    final safeEpisode = _sanitizeFileName(episodeName);
    return '${_downloadDir.path}/$safeAnime/$safeEpisode.mp4';
  }

  /// 检查是否已下载完成
  Future<bool> isDownloaded(String episodeUrl) async {
    _ensureInitialized();
    final item = _downloadBox.get(episodeUrl);
    if (item == null) return false;
    if (item.status != 2 || item.localPath == null) return false;
    return File(item.localPath!).existsSync();
  }

  /// 获取本地文件路径（用于播放）
  String? getLocalPath(String episodeUrl) {
    _ensureInitialized();
    final item = _downloadBox.get(episodeUrl);
    if (item == null || item.status != 2) return null;
    if (item.localPath == null) return null;
    if (!File(item.localPath!).existsSync()) return null;
    return item.localPath;
  }

  /// 获取活跃下载数量
  int get activeDownloadCount =>
      _activeTasks.values.where((t) => t.status == 1).length;

  // ============================================================
  // 队列调度
  // ============================================================

  void _processQueue() {
    if (activeDownloadCount >= _maxConcurrent) return;

    // 找到等待中的任务，按创建时间排序
    final waiting = _activeTasks.values
        .where((t) => t.status == 0)
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    for (final item in waiting) {
      if (activeDownloadCount >= _maxConcurrent) break;
      _startDownload(item);
    }
  }

  // ============================================================
  // M3U8 下载核心
  // ============================================================

  Future<void> _startDownload(DownloadItem item) async {
    item.status = 1; // 下载中
    await item.save();

    final cancelToken = CancelToken();
    _activeTokens[item.episodeUrl] = cancelToken;

    Log.d('Download', '开始下载: ${item.animeName} - ${item.episodeName}');

    try {
      // 1. 获取 m3u8 playlist
      final playlistContent = await _fetchPlaylist(item.m3u8Url, item.referer, cancelToken);
      if (cancelToken.isCancelled) return;

      // 2. 解析分片 URL
      var segmentUrls = _parseSegments(playlistContent, item.m3u8Url);
      if (segmentUrls.isEmpty) {
        throw Exception('M3U8 解析失败：没有找到分片');
      }

      // 安全回退：如果解析出的是 m3u8 子链接而非 ts 分片，重新获取子播放列表
      if (segmentUrls.length == 1 && segmentUrls.first.contains('.m3u8')) {
        Log.d('Download', '子播放列表回退: ${segmentUrls.first}');
        final subContent = await _fetchPlaylist(segmentUrls.first, item.referer, cancelToken);
        segmentUrls = _parseSegments(subContent, segmentUrls.first);
        if (segmentUrls.isEmpty) {
          throw Exception('M3U8 子播放列表解析失败：没有找到分片');
        }
      }

      item.totalSegments = segmentUrls.length;
      await item.save();
      Log.d('Download', '共 ${segmentUrls.length} 个分片');

      // 3. 准备临时目录和最终文件路径
      final safeAnime = _sanitizeFileName(item.animeName);
      final safeEpisode = _sanitizeFileName(item.episodeName);
      final animeDir = Directory('${_downloadDir.path}/$safeAnime');
      if (!await animeDir.exists()) {
        await animeDir.create(recursive: true);
      }

      final tempDir = Directory('${animeDir.path}/.tmp_$safeEpisode');
      if (!await tempDir.exists()) {
        await tempDir.create(recursive: true);
      }

      final outputPath = '${animeDir.path}/$safeEpisode.mp4';

      // 4. 下载每个分片（从已下载的分片继续）
      int startIndex = item.downloadedSegments;
      for (int i = startIndex; i < segmentUrls.length; i++) {
        if (cancelToken.isCancelled) return;

        final segmentFile = File('${tempDir.path}/seg_$i.ts');
        // 如果分片已存在（断点续传），跳过下载
        if (!await segmentFile.exists()) {
          final segmentData = await _fetchSegment(
            segmentUrls[i],
            item.referer,
            cancelToken,
          );
          if (cancelToken.isCancelled) return;
          await segmentFile.writeAsBytes(segmentData);
        }

        item.downloadedSegments = i + 1;
        item.progress = (i + 1) / segmentUrls.length;
        await item.save();
      }

      if (cancelToken.isCancelled) return;

      // 5. 合并所有分片为 .mp4 文件
      Log.d('Download', '合并分片...');
      final outputFile = File(outputPath);
      final sink = outputFile.openWrite();
      for (int i = 0; i < segmentUrls.length; i++) {
        final segmentFile = File('${tempDir.path}/seg_$i.ts');
        if (await segmentFile.exists()) {
          sink.add(await segmentFile.readAsBytes());
        }
      }
      await sink.flush();
      await sink.close();

      // 6. 清理临时文件
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }

      // 7. 更新状态为已完成
      item.status = 2;
      item.progress = 1.0;
      item.localPath = outputPath;
      await item.save();

      Log.d('Download', '下载完成: ${item.episodeName} -> $outputPath');
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) {
        Log.d('Download', '下载被取消: ${item.episodeName}');
        // 检查是否是用户主动操作（pauseDownload/cancelDownload 已移除 token）
        final isUserAction = !_activeTokens.containsKey(item.episodeUrl);
        if (isUserAction) {
          // 用户主动暂停/取消：保留当前状态（已被 pauseDownload/cancelDownload 设置）
          Log.d('Download', '用户主动操作，保留状态: ${item.status}');
        } else {
          // 异常中断：标记为失败，释放槽位
          Log.d('Download', '异常中断，标记为失败');
          item.status = 4;
          await item.save();
        }
        return;
      }

      Log.e('Download', '下载失败: ${item.episodeName}', e);
      item.status = 4; // 失败
      // DEBUG: 写错误详情到文件
      try {
        final f = File('${_downloadDir.path}/error_log.txt');
        f.writeAsStringSync(
          '[${DateTime.now()}] ${item.episodeName}\n'
          'URL: ${item.m3u8Url}\n'
          'Referer: ${item.referer}\n'
          'sourcePlugin: ${item.sourcePlugin}\n'
          'Error: $e\n\n',
          mode: FileMode.append,
        );
      } catch (_) {}
      await item.save();
    } finally {
      _activeTokens.remove(item.episodeUrl);
      _processQueue(); // 尝试启动下一个任务
    }
  }

  /// 获取 m3u8 playlist 内容（支持多层嵌套 playlist）
  Future<String> _fetchPlaylist(
    String url,
    String? referer,
    CancelToken cancelToken,
  ) async {
    final options = Options(
      responseType: ResponseType.plain,
      headers: {
        if (referer != null) 'Referer': referer,
      },
    );

    final response = await _dio.get<String>(
      url,
      options: options,
      cancelToken: cancelToken,
    );
    final content = response.data ?? '';

    // 检查是否是 master playlist（包含其他 m3u8 链接）
    // 如果包含 #EXT-X-STREAM-INF，说明是 master playlist，取第一个
    if (content.contains('#EXT-X-STREAM-INF')) {
      final lines = content.split('\n');
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isNotEmpty &&
            !trimmed.startsWith('#') &&
            trimmed.endsWith('.m3u8')) {
          final subUrl = _resolveUrl(trimmed, url);
          Log.d('Download', 'Master playlist -> $subUrl');
          return await _fetchPlaylist(subUrl, referer, cancelToken);
        }
      }
    }

    return content;
  }

  /// 解析 m3u8 playlist，提取 .ts 分片 URL
  /// 如果检测到是 master playlist（包含 .m3u8 子链接），返回空让调用方处理
  List<String> _parseSegments(String playlistContent, String baseUrl) {
    final segments = <String>[];
    final m3u8Links = <String>[];
    final lines = const LineSplitter().convert(playlistContent);

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      if (trimmed.startsWith('#')) continue;

      // 检测是否包含 .m3u8 子链接（可能是未被 _fetchPlaylist 识别的 master playlist）
      if (trimmed.contains('.m3u8')) {
        m3u8Links.add(_resolveUrl(trimmed, baseUrl));
        continue;
      }

      // 这是一个分片 URL（可能是相对路径或绝对路径）
      final segmentUrl = _resolveUrl(trimmed, baseUrl);
      segments.add(segmentUrl);
    }

    // 如果有 .m3u8 子链接但没有 ts 分片，说明是 master playlist
    if (m3u8Links.isNotEmpty && segments.isEmpty) {
      Log.d('Download', '检测到 master playlist（无 #EXT-X-STREAM-INF），子链接: ${m3u8Links.first}');
      // 返回子链接的第一个 m3u8 作为唯一"分片"，让 _startDownload 重新解析
      // 实际上这不应该发生，因为 _fetchPlaylist 应该已经处理了
      // 但作为安全回退，返回子链接让上层知道需要重新获取
      return m3u8Links;
    }

    return segments;
  }

  /// 下载单个 .ts 分片
  Future<List<int>> _fetchSegment(
    String url,
    String? referer,
    CancelToken cancelToken,
  ) async {
    final options = Options(
      responseType: ResponseType.bytes,
      headers: {
        if (referer != null) 'Referer': referer,
      },
    );

    final response = await _dio.get<List<int>>(
      url,
      options: options,
      cancelToken: cancelToken,
    );

    return response.data ?? [];
  }

  // ============================================================
  // 工具方法
  // ============================================================

  /// 解析相对 URL
  String _resolveUrl(String relative, String base) {
    if (relative.startsWith('http://') || relative.startsWith('https://')) {
      return relative;
    }

    final baseUri = Uri.parse(base);

    if (relative.startsWith('//')) {
      return '${baseUri.scheme}:$relative';
    }

    if (relative.startsWith('/')) {
      return '${baseUri.scheme}://${baseUri.host}'
          '${baseUri.port != 80 && baseUri.port != 443 ? ':${baseUri.port}' : ''}'
          '$relative';
    }

    // 相对路径：基于 baseUrl 的目录
    final basePath = baseUri.path;
    final lastSlash = basePath.lastIndexOf('/');
    final baseDir = lastSlash >= 0 ? basePath.substring(0, lastSlash + 1) : '/';
    return '${baseUri.scheme}://${baseUri.host}'
        '${baseUri.port != 80 && baseUri.port != 443 ? ':${baseUri.port}' : ''}'
        '$baseDir$relative';
  }

  /// 清理下载文件（临时文件 + 最终文件）
  Future<void> _cleanupFiles(DownloadItem item) async {
    try {
      if (item.localPath != null) {
        final file = File(item.localPath!);
        if (await file.exists()) {
          await file.delete();
        }
      }

      // 清理临时目录
      final safeAnime = _sanitizeFileName(item.animeName);
      final safeEpisode = _sanitizeFileName(item.episodeName);
      final tempDir = Directory(
        '${_downloadDir.path}/$safeAnime/.tmp_$safeEpisode',
      );
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    } catch (e) {
      Log.e('Download', '清理文件失败', e);
    }
  }

  /// 文件名安全化：移除非法字符
  String _sanitizeFileName(String name) {
    return name
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// 从 m3u8 URL 的 CDN 域名推导正确的 Referer
  String? _getRefererForCdn(String m3u8Url) {
    try {
      final host = Uri.parse(m3u8Url).host;
      // CDN 域名 → CMS 站点域名映射
      if (host.contains('ffzy') || host.contains('ffzy-plays')) {
        return 'https://cj.ffzyapi.com/';
      }
      if (host.contains('yinhua')) {
        return 'https://www.yinhuadm.xyz/';
      }
      // 回退：用 URL 自身 origin
      final uri = Uri.parse(m3u8Url);
      return '${uri.scheme}://${uri.host}/';
    } catch (_) {
      return null;
    }
  }
}
