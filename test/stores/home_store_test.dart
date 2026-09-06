import 'package:flutter_test/flutter_test.dart';
import 'package:weila/services/home/home_feed_service.dart';
import 'package:weila/stores/home_store.dart';

class _ScriptedFeed implements HomeFeedDataSource {
  _ScriptedFeed({
    this.latest,
    this.trending,
    this.seasonal,
  });

  final Object? latest; // List 或 Exception
  final Object? trending;
  final Object? seasonal;

  List<Map<String, dynamic>> _result(Object? script) {
    if (script is Exception) throw script;
    return (script as List<Map<String, dynamic>>?) ?? [];
  }

  @override
  Future<List<Map<String, dynamic>>> loadLatest() async => _result(latest);

  @override
  Future<List<Map<String, dynamic>>> loadTrending() async => _result(trending);

  @override
  Future<List<Map<String, dynamic>>> loadSeasonal() async => _result(seasonal);
}

void main() {
  List<Map<String, dynamic>> items(String key) => [
        {'name': key},
      ];

  test('三个流的错误互相隔离，不再串台', () async {
    final store = HomeStore(
      feedService: _ScriptedFeed(
        latest: Exception('net down'),
        trending: items('trending'),
        seasonal: items('seasonal'),
      ),
    );

    await store.loadAll();

    expect(store.latestError, '加载最新番剧失败，请检查网络');
    expect(store.trendingError, isNull);
    expect(store.seasonalError, isNull);
    expect(store.errorMessage, store.latestError);
    // 成功的流照常填充
    expect(store.trendingList.single['name'], 'trending');
    expect(store.seasonalList.single['name'], 'seasonal');
    expect(store.latestList, isEmpty);
  });

  test('季度新番失败也会记录错误（此前静默）', () async {
    final store = HomeStore(
      feedService: _ScriptedFeed(
        latest: items('latest'),
        trending: items('trending'),
        seasonal: Exception('net down'),
      ),
    );

    await store.loadSeasonal();

    expect(store.seasonalError, '加载季度新番失败，请检查网络');
    expect(store.latestError, isNull);
    expect(store.trendingError, isNull);
  });

  test('重试成功后清掉本流的旧错误', () async {
    var failing = true;
    final feed = _StubSwitchableFeed(() => failing);
    final store = HomeStore(feedService: feed);

    await store.loadLatest();
    expect(store.latestError, isNotNull);

    failing = false;
    await store.loadLatest();
    expect(store.latestError, isNull);
    expect(store.latestList.single['name'], 'ok');
  });
}

class _StubSwitchableFeed implements HomeFeedDataSource {
  _StubSwitchableFeed(this._failLatest);

  final bool Function() _failLatest;

  @override
  Future<List<Map<String, dynamic>>> loadLatest() async {
    if (_failLatest()) throw Exception('net down');
    return [
      {'name': 'ok'},
    ];
  }

  @override
  Future<List<Map<String, dynamic>>> loadTrending() async => [];

  @override
  Future<List<Map<String, dynamic>>> loadSeasonal() async => [];
}
