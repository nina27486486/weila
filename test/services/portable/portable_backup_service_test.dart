import 'package:flutter_test/flutter_test.dart';
import 'package:weila/models/collect_item.dart';
import 'package:weila/models/history_item.dart';
import 'package:weila/models/track_item.dart';
import 'package:weila/services/portable/portable_backup_service.dart';
import 'package:weila/services/portable/weila_portable_backup.dart';

class _MemoryStore implements PortableLibraryStore {
  final favorites = <String, CollectItem>{};
  final following = <String, TrackItem>{};
  final history = <String, HistoryItem>{};
  final settings = <String, Object>{};

  @override
  List<CollectItem> getFavorites() => favorites.values.toList();

  @override
  List<TrackItem> getFollowing() => following.values.toList();

  @override
  List<HistoryItem> getHistory() => history.values.toList()
    ..sort((a, b) => b.watchedAt.compareTo(a.watchedAt));

  @override
  Future<void> putFavorite(CollectItem item) async {
    favorites[item.animeUrl] = item;
  }

  @override
  Future<void> removeFavorite(String animeUrl) async {
    favorites.remove(animeUrl);
  }

  @override
  Future<void> putFollowing(TrackItem item) async {
    following[item.animeUrl] = item;
  }

  @override
  Future<void> removeFollowing(String animeUrl) async {
    following.remove(animeUrl);
  }

  @override
  Future<void> putHistory(HistoryItem item) async {
    history[item.animeUrl] = item;
  }

  @override
  Future<void> removeHistory(String animeUrl) async {
    history.remove(animeUrl);
  }

  @override
  Object? readSetting(String key) => settings[key];

  @override
  Future<void> writeSetting(String key, Object value) async {
    settings[key] = value;
  }
}

void main() {
  late _MemoryStore store;
  late PortableBackupService service;

  setUp(() {
    store = _MemoryStore();
    service = PortableBackupService(store: store, appVersion: () => '1.0.0');
  });

  test('导出 → 清空 → 导入完整还原', () async {
    await store.putFavorite(CollectItem(
      animeName: '作品A',
      animeUrl: 'cms_x:1',
      sourcePlugin: 'cms_x',
      contentId: 'ct-1',
      collectedAt: DateTime.utc(2026, 9, 1),
    ));
    await store.putHistory(HistoryItem(
      animeName: '作品A',
      animeUrl: 'cms_x:1',
      episodeName: '第 2 集',
      episodeUrl: 'cms_x:1/ep/2',
      sourcePlugin: 'cms_x',
      position: const Duration(minutes: 5),
      duration: const Duration(minutes: 24),
      contentId: 'ct-1',
      watchedAt: DateTime.utc(2026, 9, 2),
    ));
    store.settings['isDarkMode'] = true;

    final json = await service.exportJson();
    final restored = _MemoryStore();
    final importer =
        PortableBackupService(store: restored, appVersion: () => '1.0.0');
    final report = await importer.importJson(json);

    expect(report.totalEntries, 2);
    expect(report.settingsApplied, 1);
    expect(restored.getFavorites(), hasLength(1));
    expect(restored.getFavorites().single.contentId, 'ct-1');
    expect(restored.getHistory(), hasLength(1));
    expect(restored.getHistory().single.position, const Duration(minutes: 5));
    expect(restored.settings['isDarkMode'], isTrue);
  });

  test('导入失败不写入任何数据', () async {
    await store.putFavorite(CollectItem(
      animeName: '已有',
      animeUrl: 'cms_x:9',
      sourcePlugin: 'cms_x',
    ));
    final before = store.getFavorites().length;

    expect(
      () => service.importJson('{"schemaVersion": 999}'),
      throwsA(isA<PortableBackupFormatException>()),
    );
    expect(store.getFavorites().length, before);
  });

  test('历史合并保留最新时间与最大进度', () async {
    await store.putHistory(HistoryItem(
      animeName: '作品B',
      animeUrl: 'cms_x:2',
      episodeName: '第 1 集',
      episodeUrl: 'cms_x:2/ep/1',
      sourcePlugin: 'cms_x',
      position: const Duration(minutes: 20),
      watchedAt: DateTime.utc(2026, 9, 1),
      contentId: 'ct-2',
    ));

    final json = await service.exportJson();
    // 修改 JSON：同身份新时间但更小的进度。
    final newer = json.replaceFirst(
      '"watchedAt": "2026-09-01T00:00:00.000Z"',
      '"watchedAt": "2026-10-01T00:00:00.000Z"',
    );
    final report = await service.importJson(newer);

    expect(report.historyApplied, 1);
    final merged = store.getHistory().single;
    expect(merged.watchedAt, DateTime.utc(2026, 10, 1));
    expect(merged.position, const Duration(minutes: 20));
    expect(store.getHistory(), hasLength(1), reason: '同身份不产生重复记录');
  });

  test('contentId 身份跨 animeUrl 换源合并，不留双记录', () async {
    await store.putFavorite(CollectItem(
      animeName: '旧源名',
      animeUrl: 'cms_old:7',
      sourcePlugin: 'cms_old',
      contentId: 'ct-77',
      collectedAt: DateTime.utc(2026, 9, 1),
    ));

    final backup = WeilaPortableBackupV1(
      exportedAtUtc: DateTime.utc(2026, 10, 25),
      appVersion: '1.0.0',
      favorites: [
        {
          'contentId': 'ct-77',
          'animeUrl': 'cms_new:7',
          'animeName': '新源名',
          'sourcePlugin': 'cms_new',
          'cover': null,
          'description': null,
          'collectedAt': '2026-10-01T00:00:00.000Z',
        },
      ],
      history: const [],
      following: const [],
      safeSettings: const {},
    );

    await service.importJson(backup.encodeJson());

    expect(store.getFavorites(), hasLength(1));
    expect(store.getFavorites().single.animeUrl, 'cms_new:7');
    expect(store.getFavorites().single.animeName, '新源名');
  });

  test('追番合并保留较大的观看进度', () async {
    await store.putFollowing(TrackItem(
      animeName: '作品C',
      animeUrl: 'cms_x:3',
      sourcePlugin: 'cms_x',
      watchedEpisodes: 8,
      totalEpisodes: 12,
      contentId: 'ct-3',
      trackedAt: DateTime.utc(2026, 9, 1),
    ));

    final backup = WeilaPortableBackupV1(
      exportedAtUtc: DateTime.utc(2026, 10, 25),
      appVersion: '1.0.0',
      favorites: const [],
      history: const [],
      following: [
        {
          'contentId': 'ct-3',
          'animeUrl': 'cms_x:3',
          'animeName': '作品C',
          'sourcePlugin': 'cms_x',
          'cover': null,
          'status': null,
          'totalEpisodes': 12,
          'watchedEpisodes': 3,
          'trackedAt': '2026-10-01T00:00:00.000Z',
        },
      ],
      safeSettings: const {},
    );

    await service.importJson(backup.encodeJson());

    final merged = store.getFollowing().single;
    expect(merged.watchedEpisodes, 8, reason: '较新状态但进度更小，保留 8');
    expect(merged.trackedAt, DateTime.utc(2026, 10, 1));
  });

  test('导出不含敏感设置', () async {
    store.settings['isDarkMode'] = false;
    store.settings['download_proxy_mode'] = 'custom';
    store.settings['danmaku_app_secret'] = 'secret';

    final json = await service.exportJson();

    expect(json.contains('download_proxy_mode'), isFalse);
    expect(json.contains('danmaku_app_secret'), isFalse);
    expect(json.contains('isDarkMode'), isTrue);
  });
}
