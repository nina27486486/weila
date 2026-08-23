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
  late Box _settingsBox;
  late Box _danmakuCacheBox;
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
    _settingsBox = await Hive.openBox(AppConstants.boxSettings);
    _danmakuCacheBox = await Hive.openBox(AppConstants.boxDanmakuCache);
    await _migrateLegacyDanmakuCache();
    _catalogStores = CatalogHiveStores(
      entriesBox: await Hive.openBox<Object?>(catalogEntriesStoreName),
      referencesBox: await Hive.openBox<Object?>(catalogReferencesStoreName),
      queryCacheBox: await openRecoverableCatalogCacheBox(
        name: catalogQueryCacheStoreName,
        openBox: Hive.openBox<Object?>,
        deleteBoxFromDisk: Hive.deleteBoxFromDisk,
      ),
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
    try {
      await _historyBox.put(item.animeUrl, item);
    } catch (error) {
      Log.e('Storage', '写入历史失败', error);
    }
  }

  @override
  Future<void> removeHistory(String animeUrl) async {
    try {
      await _historyBox.delete(animeUrl);
    } catch (error) {
      Log.e('Storage', '删除历史失败', error);
    }
  }

  @override
  Future<void> clearHistory() async {
    try {
      await _historyBox.clear();
    } catch (error) {
      Log.e('Storage', '清空历史失败', error);
    }
  }

  // === 收藏 ===
  @override
  List<CollectItem> getCollects() => _collectBox.values.toList()
    ..sort((a, b) => b.collectedAt.compareTo(a.collectedAt));

  @override
  Future<void> addCollect(CollectItem item) async {
    try {
      await _collectBox.put(item.animeUrl, item);
    } catch (error) {
      Log.e('Storage', '写入收藏失败', error);
    }
  }

  @override
  Future<void> removeCollect(String animeUrl) async {
    try {
      await _collectBox.delete(animeUrl);
    } catch (error) {
      Log.e('Storage', '删除收藏失败', error);
    }
  }

  @override
  bool isCollected(String animeUrl) => _collectBox.containsKey(animeUrl);

  // === 追番 ===
  @override
  List<TrackItem> getTracks() => _trackBox.values.toList()
    ..sort((a, b) => b.trackedAt.compareTo(a.trackedAt));

  @override
  Future<void> addTrack(TrackItem item) async {
    try {
      await _trackBox.put(item.animeUrl, item);
    } catch (error) {
      Log.e('Storage', '写入追番失败', error);
    }
  }

  @override
  Future<void> removeTrack(String animeUrl) async {
    try {
      await _trackBox.delete(animeUrl);
    } catch (error) {
      Log.e('Storage', '删除追番失败', error);
    }
  }

  @override
  bool isTracked(String animeUrl) => _trackBox.containsKey(animeUrl);

  Future<void> updateTrackProgress(String animeUrl, int watchedEpisodes) async {
    try {
      final item = _trackBox.get(animeUrl);
      if (item != null) {
        item.watchedEpisodes = watchedEpisodes;
        item.lastUpdated = DateTime.now();
        await item.save();
      }
    } catch (error) {
      Log.e('Storage', '更新追番进度失败', error);
    }
  }

  // === 设置 ===
  T? getSetting<T>(String key, {T? defaultValue}) {
    final value = _settingsBox.get(key, defaultValue: defaultValue);
    if (value is T) return value;
    if (value != null) {
      // 存量值类型与期望不符（如旧版本写入格式变化）：回退默认值而不是抛
      // TypeError 让整页崩溃，并留下日志便于排查。
      Log.e(
        'Storage',
        '设置 $key 的存储类型 $T 不匹配（实际 ${value.runtimeType}），已回退默认值',
      );
    }
    return defaultValue;
  }

  Future<void> setSetting(String key, dynamic value) async {
    try {
      await _settingsBox.put(key, value);
    } catch (error) {
      Log.e('Storage', '写入设置 $key 失败', error);
    }
  }

  Future<void> removeSetting(String key) async {
    try {
      await _settingsBox.delete(key);
    } catch (error) {
      Log.e('Storage', '删除设置 $key 失败', error);
    }
  }

  // === 弹幕缓存（独立 box：单集可达数百 KB，避免混入设置存储） ===
  static const List<String> _danmakuCacheKeys = [
    'danmaku_search_cache_v1',
    'danmaku_match_cache_v1',
    'danmaku_comment_cache_v1',
  ];

  Object? getDanmakuCache(String key) {
    _ensureInitialized();
    return _danmakuCacheBox.get(key);
  }

  Future<void> setDanmakuCache(String key, Object value) async {
    try {
      await _danmakuCacheBox.put(key, value);
    } catch (error) {
      Log.e('Storage', '写入弹幕缓存失败', error);
    }
  }

  Future<void> removeDanmakuCache(String key) async {
    try {
      await _danmakuCacheBox.delete(key);
    } catch (error) {
      Log.e('Storage', '删除弹幕缓存失败', error);
    }
  }

  /// 一次性迁移：老版本把弹幕缓存放在 settings box 里，搬到独立 box
  /// 后把旧键清掉，避免设置存储持续膨胀。
  Future<void> _migrateLegacyDanmakuCache() async {
    try {
      var migrated = false;
      for (final key in _danmakuCacheKeys) {
        if (_settingsBox.containsKey(key)) {
          final value = _settingsBox.get(key);
          if (value != null && !_danmakuCacheBox.containsKey(key)) {
            await _danmakuCacheBox.put(key, value);
          }
          await _settingsBox.delete(key);
          migrated = true;
        }
      }
      if (migrated) {
        Log.d('Storage', '弹幕缓存已迁移到独立 box');
      }
    } catch (error) {
      Log.e('Storage', '迁移弹幕缓存失败（忽略，将重新匹配）', error);
    }
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
      await setSetting(entry.key, entry.value);
    }
  }
}
