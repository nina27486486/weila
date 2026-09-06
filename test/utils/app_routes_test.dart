import 'package:flutter_test/flutter_test.dart';
import 'package:weila/utils/app_routes.dart';

void main() {
  group('AppRoutes.detail', () {
    test('url 与 name 被编码拼接', () {
      final uri = AppRoutes.detail(
        url: 'cms_yinhua:24840',
        name: '幼女战记 第二季 & 番外',
      );
      expect(uri, startsWith('/detail?'));
      // 冒号、& 与空格都应被编码，不会破坏 query 结构
      expect(uri, contains('url=cms_yinhua%3A24840'));
      expect(uri, contains( Uri.encodeComponent('幼女战记 第二季 & 番外')));
    });

    test('空值参数被过滤', () {
      expect(
        AppRoutes.detail(url: 'u', name: null, contentId: ''),
        '/detail?url=u',
      );
    });

    test('全部为空时返回裸路径', () {
      expect(AppRoutes.detail(), '/detail');
    });
  });

  group('AppRoutes.player', () {
    test('完整参数生成有序 query', () {
      final uri = AppRoutes.player(
        url: 'https://v.example.com/hls/index.m3u8?token=a b',
        title: '第 1 集',
        animeUrl: 'cms_ffzy:99',
        animeName: '测试番剧',
        cover: 'https://img.example.com/c.jpg',
        episodeIndex: 3,
        source: 'cms_ffzy',
        contentId: 'ct-1',
      );
      expect(uri, startsWith('/player?'));
      expect(uri, contains('ep=3'));
      expect(uri, contains('source=cms_ffzy'));
      expect(uri, contains('contentId=ct-1'));
      expect(
        uri,
        contains('url=${Uri.encodeComponent('https://v.example.com/hls/index.m3u8?token=a b')}'),
      );
    });

    test('仅必填 url 时不带 ep 等空参数', () {
      expect(AppRoutes.player(url: 'u'), '/player?url=u');
    });

    test('episodeIndex 0 也会显式传递', () {
      expect(
        AppRoutes.player(url: 'u', episodeIndex: 0),
        '/player?url=u&ep=0',
      );
    });
  });

  test('路由常量与模块注册路径一致', () {
    expect(AppRoutes.home, '/');
    expect(AppRoutes.search, '/search');
    expect(AppRoutes.detailPath, '/detail');
    expect(AppRoutes.playerPath, '/player');
    expect(AppRoutes.plugins, '/settings/plugins');
    expect(AppRoutes.pluginAdd, '/settings/plugin-add');
    expect(AppRoutes.pluginDetail, '/settings/plugin-detail');
  });
}
