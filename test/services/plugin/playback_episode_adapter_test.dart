import 'package:flutter_test/flutter_test.dart';
import 'package:weila/models/anime.dart';
import 'package:weila/models/playback/playback_source.dart';
import 'package:weila/models/plugin.dart';
import 'package:weila/services/playback/plugin_playback_episode_adapter.dart';
import 'package:weila/services/plugin/plugin_service.dart';

void main() {
  const adapter = PluginPlaybackEpisodeAdapter();

  Plugin buildPlugin({String? referer = 'https://site.example/'}) {
    return Plugin(
      api: 'html_test',
      name: '测试源',
      baseUrl: 'https://site.example',
      searchURL: '',
      searchList: '',
      searchName: '',
      searchResult: '',
      chapterRoads: '',
      chapterResult: '',
      userAgent: 'Weila-Test',
      referer: referer,
    );
  }

  test('wraps ordinary plugin candidates in one labelled route', () {
    final episode = Episode(name: '第 3 集', url: '/episode/3', index: 3);

    final playback = adapter.fromHtml(
      episode: episode,
      plugin: buildPlugin(),
      urls: const [
        'https://cdn.example/a.m3u8',
        'https://cdn.example/b.m3u8',
        'https://cdn.example/c.mp4',
      ],
    );

    expect(playback.name, '第 3 集');
    expect(playback.index, 3);
    expect(playback.sources, hasLength(1));
    final source = playback.sources.single;
    expect(source.id, 'html-default');
    expect(source.label, '默认线路');
    expect(source.kind, PlaybackSourceKind.html);
    expect(source.headers, {
      'User-Agent': 'Weila-Test',
      'Referer': 'https://site.example/',
    });
    expect(source.variants.map((variant) => variant.id), [
      'html-0',
      'html-1',
      'html-2',
    ]);
    expect(source.variants.map((variant) => variant.label), [
      '原始 1',
      '原始 2',
      '原始 3',
    ]);
  });

  test('drops blank and duplicate candidate URLs', () {
    final playback = adapter.fromHtml(
      episode: Episode(name: '第 1 集', url: '/episode/1', index: 1),
      plugin: buildPlugin(referer: ''),
      urls: const [
        ' https://cdn.example/episode.m3u8 ',
        '',
        'https://cdn.example/episode.m3u8',
      ],
    );

    final source = playback.sources.single;
    expect(source.variants, hasLength(1));
    expect(source.variants.single.label, '原始');
    expect(source.variants.single.url, 'https://cdn.example/episode.m3u8');
    expect(source.headers, {'User-Agent': 'Weila-Test'});
  });

  test('returns an episode without sources when no candidate is playable', () {
    final playback = adapter.fromHtml(
      episode: Episode(name: '第 1 集', url: '/episode/1', index: 1),
      plugin: buildPlugin(),
      urls: const ['', '   '],
    );

    expect(playback.sources, isEmpty);
  });

  test('PluginService exposes runtime playback episode APIs', () {
    final service = PluginService();

    expect(service.getPlaybackEpisodes, isNotNull);
    expect(service.resolvePlaybackEpisode, isNotNull);
  });
}
