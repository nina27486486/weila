import 'package:flutter_test/flutter_test.dart';
import 'package:weila/services/home/home_feed_service.dart';

class _FakeHomeCatalogGateway implements HomeCatalogGateway {
  final Map<String, List<Map<String, dynamic>>> cmsResults = {};
  List<Map<String, dynamic>> seasonal = const [];
  List<Map<String, dynamic>> popular = const [];
  final List<String> calls = [];

  @override
  Future<List<Map<String, dynamic>>> getCmsLatest(String pluginApi) async {
    calls.add('cms:$pluginApi');
    return cmsResults[pluginApi] ?? const [];
  }

  @override
  Future<List<Map<String, dynamic>>> getPopularAnime() async {
    calls.add('popular');
    return popular;
  }

  @override
  Future<List<Map<String, dynamic>>> getSeasonalAnime() async {
    calls.add('seasonal');
    return seasonal;
  }
}

void main() {
  test('seasonal feed is returned without waiting for playable-source matching',
      () async {
    final gateway = _FakeHomeCatalogGateway()
      ..seasonal = [
        {'name': '本季动画', 'url': 'jikan:1'},
      ];
    final service = HomeFeedService(gateway: gateway);

    final result = await service.loadSeasonal();

    expect(result.single['name'], '本季动画');
    expect(gateway.calls, ['seasonal']);
  });

  test('trending feed falls back when the primary CMS source is empty',
      () async {
    final gateway = _FakeHomeCatalogGateway()
      ..popular = [
        {'name': '上升作品', 'url': 'jikan:2'},
      ];
    final service = HomeFeedService(gateway: gateway);

    final result = await service.loadTrending();

    expect(result.single['name'], '上升作品');
    expect(gateway.calls, ['cms:cms_ffzy', 'popular']);
  });

  test('seasonal feed falls back to a CMS list when metadata API fails',
      () async {
    final gateway = _FakeHomeCatalogGateway()
      ..cmsResults['cms_yinhua'] = [
        {'name': '可播放新番', 'url': 'cms_yinhua:1'},
      ];
    final service = HomeFeedService(gateway: gateway);

    final result = await service.loadSeasonal();

    expect(result.single['name'], '可播放新番');
    expect(gateway.calls, ['seasonal', 'cms:cms_yinhua']);
  });
}
