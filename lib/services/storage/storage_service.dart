import 'package:hive_ce_flutter/hive_flutter.dart';
import '../../utils/logger.dart';
import '../../models/plugin.dart';
import '../../models/anime.dart';
import '../../models/history_item.dart';
import '../../models/collect_item.dart';
import '../../models/track_item.dart';
import '../../models/download_item.dart';
import '../../models/danmaku_item.dart';
import '../download/download_settings.dart';
import '../catalog/catalog_hive_stores.dart';
import '../catalog/hive_catalog_repository.dart';
import '../library/history_collect_repository.dart';
import '../../utils/constants.dart';

class StorageService
    implements HistoryCollectRepository, DownloadSettingsRepository {
  static final StorageService _instance = StorageService._();
  factory StorageService() => _instance;
  StorageService._();

  bool _initialized = false;

  late Box<HistoryItem> _historyBox;
  late Box<CollectItem> _collectBox;
  late Box<TrackItem> _trackBox;
  late Box<DownloadItem> _downloadBox;
  late Box _settingsBox;
  late CatalogHiveStores _catalogStores;

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
    _catalogStores = CatalogHiveStores(
      entriesBox: await Hive.openBox<Object?>(catalogEntriesStoreName),
      referencesBox: await Hive.openBox<Object?>(catalogReferencesStoreName),
      queryCacheBox: await Hive.openBox<Object?>(catalogQueryCacheStoreName),
    );
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
  @override
  List<HistoryItem> getHistory() {
    _ensureInitialized();
    return _historyBox.values.toList()
      ..sort((a, b) => b.watchedAt.compareTo(a.watchedAt));
  }

  @override
  Future<void> addHistory(HistoryItem item) async {
    await _historyBox.put(item.animeUrl, item);
  }

  @override
  Future<void> removeHistory(String animeUrl) async {
    await _historyBox.delete(animeUrl);
  }

  @override
  Future<void> clearHistory() async {
    await _historyBox.clear();
  }

  // === 收藏 ===
  @override
  List<CollectItem> getCollects() => _collectBox.values.toList()
    ..sort((a, b) => b.collectedAt.compareTo(a.collectedAt));

  @override
  Future<void> addCollect(CollectItem item) async {
    await _collectBox.put(item.animeUrl, item);
  }

  @override
  Future<void> removeCollect(String animeUrl) async {
    await _collectBox.delete(animeUrl);
  }

  @override
  bool isCollected(String animeUrl) => _collectBox.containsKey(animeUrl);

  // === 追番 ===
  @override
  List<TrackItem> getTracks() => _trackBox.values.toList()
    ..sort((a, b) => b.trackedAt.compareTo(a.trackedAt));

  @override
  Future<void> addTrack(TrackItem item) async {
    await _trackBox.put(item.animeUrl, item);
  }

  @override
  Future<void> removeTrack(String animeUrl) async {
    await _trackBox.delete(animeUrl);
  }

  @override
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

  Future<void> removeSetting(String key) async {
    await _settingsBox.delete(key);
  }

  HiveCatalogRepository createCatalogRepository({
    CatalogPageLoader? loadPage,
  }) {
    _ensureInitialized();
    return HiveCatalogRepository(
      entryStore: _catalogStores.entryStore,
      referenceStore: _catalogStores.referenceStore,
      queryCacheStore: _catalogStores.queryCacheStore,
      loadPage: loadPage,
      persistStores: _catalogStores.persist,
    );
  }

  @override
  DownloadSettings getDownloadSettings() {
    _ensureInitialized();
    return DownloadSettings.fromMap({
      DownloadSettings.proxyModeKey:
          _settingsBox.get(DownloadSettings.proxyModeKey),
      DownloadSettings.customProxyKey:
          _settingsBox.get(DownloadSettings.customProxyKey),
      DownloadSettings.segmentConcurrencyKey:
          _settingsBox.get(DownloadSettings.segmentConcurrencyKey),
      DownloadSettings.segmentRetriesKey:
          _settingsBox.get(DownloadSettings.segmentRetriesKey),
    });
  }

  @override
  Future<void> setDownloadSettings(DownloadSettings settings) async {
    _ensureInitialized();
    final values = settings.toMap();
    for (final entry in values.entries) {
      await _settingsBox.put(entry.key, entry.value);
    }
  }
}
