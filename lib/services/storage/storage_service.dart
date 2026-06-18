import 'package:hive_ce_flutter/hive_flutter.dart';
import '../../utils/logger.dart';
import '../../models/plugin.dart';
import '../../models/anime.dart';
import '../../models/history_item.dart';
import '../../models/collect_item.dart';
import '../../models/track_item.dart';
import '../../models/download_item.dart';
import '../../models/danmaku_item.dart';
import '../../utils/constants.dart';

class StorageService {
  static final StorageService _instance = StorageService._();
  factory StorageService() => _instance;
  StorageService._();
  
  bool _initialized = false;
  
  late Box<HistoryItem> _historyBox;
  late Box<CollectItem> _collectBox;
  late Box<TrackItem> _trackBox;
  late Box<DownloadItem> _downloadBox;
  late Box _settingsBox;
  
  /// 初始化 Hive（防重入）
  Future<void> init() async {
    if (_initialized) return;
    
    await Hive.initFlutter();
    
    // 注册适配器
    Hive.registerAdapter(PluginAdapter());
    Hive.registerAdapter(AnimeAdapter());
    Hive.registerAdapter(EpisodeAdapter());
    Hive.registerAdapter(HistoryItemAdapter());
    Hive.registerAdapter(CollectItemAdapter());
    Hive.registerAdapter(TrackItemAdapter());
    Hive.registerAdapter(DownloadItemAdapter());
    Hive.registerAdapter(DanmakuItemAdapter());
    
    _historyBox = await Hive.openBox<HistoryItem>(AppConstants.boxHistory);
    _collectBox = await Hive.openBox<CollectItem>(AppConstants.boxCollect);
    _trackBox = await Hive.openBox<TrackItem>(AppConstants.boxTrack);
    _downloadBox = await Hive.openBox<DownloadItem>(AppConstants.boxDownload);
    _settingsBox = await Hive.openBox(AppConstants.boxSettings);
    _initialized = true;
    
    Log.d('Storage', 'Hive 初始化完成');
  }
  
  /// 检查是否已初始化
  void _ensureInitialized() {
    if (!_initialized) {
      throw StateError('StorageService 未初始化，请先调用 init()');
    }
  }
  
  // === 历史记录 ===
  List<HistoryItem> getHistory() {
    _ensureInitialized();
    return _historyBox.values.toList()
      ..sort((a, b) => b.watchedAt.compareTo(a.watchedAt));
  }
  
  Future<void> addHistory(HistoryItem item) async {
    await _historyBox.put(item.animeUrl, item);
  }
  
  Future<void> clearHistory() async {
    await _historyBox.clear();
  }
  
  // === 收藏 ===
  List<CollectItem> getCollects() => _collectBox.values.toList()
    ..sort((a, b) => b.collectedAt.compareTo(a.collectedAt));
  
  Future<void> addCollect(CollectItem item) async {
    await _collectBox.put(item.animeUrl, item);
  }
  
  Future<void> removeCollect(String animeUrl) async {
    await _collectBox.delete(animeUrl);
  }
  
  bool isCollected(String animeUrl) => _collectBox.containsKey(animeUrl);
  
  // === 追番 ===
  List<TrackItem> getTracks() => _trackBox.values.toList()
    ..sort((a, b) => b.trackedAt.compareTo(a.trackedAt));
  
  Future<void> addTrack(TrackItem item) async {
    await _trackBox.put(item.animeUrl, item);
  }
  
  Future<void> removeTrack(String animeUrl) async {
    await _trackBox.delete(animeUrl);
  }
  
  bool isTracked(String animeUrl) => _trackBox.containsKey(animeUrl);
  
  Future<void> updateTrackProgress(String animeUrl, int watchedEpisodes) async {
    final item = _trackBox.get(animeUrl);
    if (item != null) {
      item.watchedEpisodes = watchedEpisodes;
      item.lastUpdated = DateTime.now();
      await item.save();
    }
  }
  
  // === 下载 ===
  List<DownloadItem> getDownloads() {
    _ensureInitialized();
    return _downloadBox.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<void> addDownload(DownloadItem item) async {
    await _downloadBox.put('${item.animeUrl}|${item.episodeUrl}', item);
  }

  Future<void> updateDownload(DownloadItem item) async {
    await _downloadBox.put('${item.animeUrl}|${item.episodeUrl}', item);
  }

  Future<void> removeDownload(String animeUrl) async {
    final keys = _downloadBox.keys
        .where((k) => k.toString().startsWith('$animeUrl|'))
        .toList();
    for (final key in keys) {
      await _downloadBox.delete(key);
    }
  }

  Future<void> clearCompleted() async {
    final keys = _downloadBox.values
        .where((item) => item.status == 2)
        .map((item) => '${item.animeUrl}|${item.episodeUrl}')
        .toList();
    for (final key in keys) {
      await _downloadBox.delete(key);
    }
  }
  
  // === 设置 ===
  T? getSetting<T>(String key, {T? defaultValue}) {
    return _settingsBox.get(key, defaultValue: defaultValue) as T?;
  }
  
  Future<void> setSetting(String key, dynamic value) async {
    await _settingsBox.put(key, value);
  }
}
