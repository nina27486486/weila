import 'package:flutter_test/flutter_test.dart';
import 'package:weila/services/portable/weila_portable_backup.dart';

Map<String, Object?> _favorite({
  String? contentId,
  String animeUrl = 'cms_x:1',
  DateTime? collectedAt,
}) =>
    {
      'contentId': contentId,
      'animeUrl': animeUrl,
      'animeName': '作品',
      'sourcePlugin': 'cms_x',
      'cover': null,
      'description': null,
      'collectedAt':
          (collectedAt ?? DateTime.utc(2026, 10, 1)).toIso8601String(),
    };

Map<String, Object?> _history({
  String? contentId,
  String animeUrl = 'cms_x:1',
  int positionMs = 60000,
  DateTime? watchedAt,
}) =>
    {
      'contentId': contentId,
      'animeUrl': animeUrl,
      'animeName': '作品',
      'episodeName': '第 1 集',
      'episodeUrl': 'cms_x:1/ep/1',
      'sourcePlugin': 'cms_x',
      'cover': null,
      'positionMs': positionMs,
      'durationMs': 1440000,
      'watchedAt': (watchedAt ?? DateTime.utc(2026, 10, 1)).toIso8601String(),
    };

Map<String, Object?> _following({
  String? contentId,
  String animeUrl = 'cms_x:1',
  DateTime? trackedAt,
}) =>
    {
      'contentId': contentId,
      'animeUrl': animeUrl,
      'animeName': '作品',
      'sourcePlugin': 'cms_x',
      'cover': null,
      'status': null,
      'totalEpisodes': 12,
      'watchedEpisodes': 3,
      'trackedAt': (trackedAt ?? DateTime.utc(2026, 10, 1)).toIso8601String(),
    };

WeilaPortableBackupV1 _backup({
  List<Map<String, Object?>> favorites = const [],
  List<Map<String, Object?>> history = const [],
  List<Map<String, Object?>> following = const [],
  Map<String, Object?> safeSettings = const {'isDarkMode': true},
}) =>
    WeilaPortableBackupV1(
      exportedAtUtc: DateTime.utc(2026, 10, 25),
      appVersion: '1.0.0',
      favorites: favorites,
      history: history,
      following: following,
      safeSettings: safeSettings,
    );

void main() {
  group('编码往返', () {
    test('encode → decode 得到等价数据', () {
      final backup = _backup(favorites: [_favorite(contentId: 'ct-1')]);
      final restored = WeilaPortableBackupV1.decodeJson(backup.encodeJson());
      expect(restored.appVersion, '1.0.0');
      expect(restored.favorites, hasLength(1));
      expect(restored.favorites.single['contentId'], 'ct-1');
      expect(restored.safeSettings['isDarkMode'], isTrue);
    });

    test('导出的 JSON 不包含凭据、代理或插件字段', () {
      final json = _backup().encodeJson();
      for (final banned in [
        'appSecret',
        'appId',
        'proxy',
        'headers',
        'cookie',
        'referer',
        'userAgent',
        'download',
      ]) {
        expect(json.toLowerCase().contains(banned.toLowerCase()), isFalse,
            reason: '备份不得包含 $banned');
      }
    });
  });

  group('解析校验（失败即拒绝，不写任何数据）', () {
    test('拒绝坏 JSON', () {
      expect(() => WeilaPortableBackupV1.decodeJson('not json'),
          throwsA(isA<PortableBackupFormatException>()));
    });

    test('拒绝不支持的 schemaVersion', () {
      final backup = _backup();
      expect(
        () => WeilaPortableBackupV1.decodeJson(
            backup.encodeJson().replaceFirst('1,', '999,')),
        throwsA(isA<PortableBackupFormatException>()),
      );
    });

    test('拒绝缺失必填字段的条目', () {
      final broken = _history()..remove('episodeName');
      final backup = _backup(history: [broken]);
      expect(() => WeilaPortableBackupV1.decodeJson(backup.encodeJson()),
          throwsA(isA<PortableBackupFormatException>()));
    });

    test('拒绝数量超限', () {
      final huge = List.generate(
        WeilaPortableBackupV1.maximumEntriesPerList + 1,
        (_) => _history(),
      );
      final backup = _backup(history: huge);
      expect(() => WeilaPortableBackupV1.decodeJson(backup.encodeJson()),
          throwsA(isA<PortableBackupFormatException>()));
    });

    test('拒绝白名单之外的设置键值（类型错）', () {
      final backup = _backup(safeSettings: {'isDarkMode': 'yes'});
      expect(() => WeilaPortableBackupV1.decodeJson(backup.encodeJson()),
          throwsA(isA<PortableBackupFormatException>()));
    });
  });

  group('身份键', () {
    test('contentId 优先，旧记录回退 animeUrl', () {
      expect(
        portableEntryIdentity(_favorite(contentId: 'ct-9')),
        'cid:ct-9',
      );
      expect(
        portableEntryIdentity(_favorite(contentId: null)),
        'url:cms_x:1',
      );
    });
  });

  group('幂等合并', () {
    test('历史：保留最新观看时间 + 最大进度', () {
      final existing = _history(
        positionMs: 900000,
        watchedAt: DateTime.utc(2026, 10, 20),
      );
      final incoming = _history(
        positionMs: 100000,
        watchedAt: DateTime.utc(2026, 10, 25),
      );
      final merged = mergeHistoryEntry(existing, incoming);
      expect(merged['watchedAt'], incoming['watchedAt']);
      expect(merged['positionMs'], 900000);
    });

    test('历史：同一时间以导入数据为基准不丢字段', () {
      final existing = _history(positionMs: 100);
      final incoming = _history(positionMs: 100);
      final merged = mergeHistoryEntry(existing, incoming);
      expect(merged['positionMs'], 100);
    });

    test('收藏：较新的 collectedAt 胜出', () {
      final existing = _favorite(collectedAt: DateTime.utc(2026, 10, 20));
      final incoming = _favorite(collectedAt: DateTime.utc(2026, 9, 1));
      expect(
        mergeByTimestamp(existing, incoming, 'collectedAt'),
        same(existing),
      );
      expect(
        mergeByTimestamp(incoming, existing, 'collectedAt'),
        same(existing),
      );
    });

    test('追番：较新的 trackedAt 胜出', () {
      final existing = _following(trackedAt: DateTime.utc(2026, 9, 1));
      final incoming = _following(trackedAt: DateTime.utc(2026, 10, 1));
      expect(
        mergeByTimestamp(existing, incoming, 'trackedAt'),
        same(incoming),
      );
    });
  });
}
