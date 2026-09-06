import 'package:flutter_test/flutter_test.dart';
import 'package:weila/models/anime.dart';
import 'package:weila/models/plugin.dart';
import 'package:weila/services/http/http_client.dart';
import 'package:weila/services/plugin/plugin_api_client.dart';
import 'package:weila/services/plugin/plugin_defaults.dart';

/// 实现共享 HTTP 契约的替身，避免测试触网。
class _FakeHttpAdapter implements HttpAdapter {
  final dynamic Function(String url)? onGetJson;
  final Object? Function(String url)? onGetJsonError;

  _FakeHttpAdapter({this.onGetJson, this.onGetJsonError});

  @override
  Future<dynamic> getJson(String url,
      {Map<String, String>? headers,
      Duration? timeout,
      bool retry = false}) async {
    if (onGetJsonError != null) {
      throw onGetJsonError!;
    }
    if (onGetJson != null) return onGetJson!(url);
    return <String, dynamic>{};
  }

  @override
  Future<String> getHtml(String url,
      {Map<String, String>? headers,
      Duration? timeout,
      bool retry = false}) async {
    return '';
  }

  @override
  Future<dynamic> postJson(String url,
      {dynamic data,
      Map<String, String>? headers,
      Duration? timeout,
      bool retry = false}) async {
    return <String, dynamic>{};
  }
}

Plugin _cmsPlugin({String api = 'cms_yinhua'}) {
  return Plugin(
    api: api,
    name: '测试源',
    version: '1.0.0',
    baseUrl: 'https://cms.example.com',
    searchURL: 'https://cms.example.com/api.php/provide/vod/?ac=videolist&wd={keyword}',
    searchList: 'list',
    searchName: 'vod_name',
    searchResult: 'vod_id',
    chapterRoads: '',
    chapterResult: '',
    userAgent: 'test-agent',
    enabled: true,
  );
}

void main() {
  group('API 类型嗅探', () {
    late PluginApiClient client;
    setUp(() {
      client = PluginApiClient(pluginsProvider: () => []);
    });

    test('CMS 前缀与采集站 URL 都识别为 CMS', () {
      expect(client.isCmsApi(_cmsPlugin()), isTrue);
      final vodUrl = _cmsPlugin(api: 'html_source')
        ..searchURL = 'https://x.com/api.php/provide/vod/?wd={keyword}';
      expect(client.isCmsApi(vodUrl), isTrue);
    });

    test('jikan/anilist/bangumi 识别', () {
      final jikan = _cmsPlugin(api: 'jikan')
        ..baseUrl = 'https://api.jikan.moe';
      expect(client.isJikanApi(jikan), isTrue);
      final anilist = _cmsPlugin(api: 'anilist')
        ..baseUrl = 'https://graphql.anilist.co';
      expect(client.isAnilistApi(anilist), isTrue);
      final bangumi = _cmsPlugin(api: 'bangumi')
        ..baseUrl = 'https://api.bgm.tv';
      expect(client.isJsonApi(bangumi), isTrue);
    });
  });

  group('searchCms', () {
    test('解析 vod 列表并过滤非动漫分类', () async {
      final client = PluginApiClient(
        pluginsProvider: () => [],
        http: _FakeHttpAdapter(onGetJson: (url) {
          expect(url, contains('wd='));
          return {
            'list': [
              {
                'vod_id': 1,
                'vod_name': '动漫 A',
                'type_id': PluginDefaults.cmsCategories['cms_yinhua']!.first['id'],
                'vod_pic': '/cover/a.jpg',
                'vod_remarks': '更新至12集',
              },
              {
                'vod_id': 2,
                'vod_name': '电视剧 B',
                'type_id': 99, // 不在动漫分类中
              },
            ],
          };
        }),
      );

      final results = await client.searchCms(_cmsPlugin(), 'keyword');
      expect(results, hasLength(1));
      expect(results.single.name, '动漫 A');
      expect(results.single.url, 'cms_yinhua:1');
      expect(results.single.cover, 'https://cms.example.com/cover/a.jpg');
      expect(results.single.description, '更新至12集');
    });

    test('请求异常时返回空列表', () async {
      final client = PluginApiClient(
        pluginsProvider: () => [],
        http: _FakeHttpAdapter(onGetJsonError: (_) => Exception('network down')),
      );
      expect(await client.searchCms(_cmsPlugin(), 'keyword'), isEmpty);
    });
  });

  group('fixCoverUrl', () {
    test('空值与 "null" 字符串返回 null', () {
      expect(PluginApiClient.fixCoverUrl(null, 'https://x.com'), isNull);
      expect(PluginApiClient.fixCoverUrl('', 'https://x.com'), isNull);
      expect(PluginApiClient.fixCoverUrl('null', 'https://x.com'), isNull);
    });

    test('协议相对与相对路径被补全', () {
      expect(
        PluginApiClient.fixCoverUrl('//cdn.example.com/a.jpg', 'https://x.com'),
        'https://cdn.example.com/a.jpg',
      );
      expect(
        PluginApiClient.fixCoverUrl('img/a.jpg', 'https://x.com'),
        'https://x.com/img/a.jpg',
      );
      expect(
        PluginApiClient.fixCoverUrl('/img/a.jpg', 'https://x.com'),
        'https://x.com/img/a.jpg',
      );
      expect(
        PluginApiClient.fixCoverUrl('https://y.com/a.jpg', 'https://x.com'),
        'https://y.com/a.jpg',
      );
    });
  });

  group('stripHtml', () {
    test('去除标签并还原实体', () {
      expect(
        PluginApiClient.stripHtml('<p>你好&nbsp;&amp;世界</p>'),
        contains('&'),
      );
      expect(PluginApiClient.stripHtml('<br/>'), isEmpty);
    });
  });

  group('fetchCmsRecord', () {
    test('非 CMS URL（无冒号分隔）返回 null', () async {
      final client = PluginApiClient(
        pluginsProvider: () => [_cmsPlugin()],
        http: _FakeHttpAdapter(),
      );
      final anime = Anime(name: 'x', url: 'no-colon-url', sourcePlugin: 'cms_yinhua');
      expect(await client.fetchCmsRecord(anime), isNull);
    });

    test('空插件列表返回 null', () async {
      final client = PluginApiClient(
        pluginsProvider: () => [],
        http: _FakeHttpAdapter(),
      );
      final anime = Anime(name: 'x', url: 'cms_yinhua:1', sourcePlugin: 'cms_yinhua');
      expect(await client.fetchCmsRecord(anime), isNull);
    });
  });
}
