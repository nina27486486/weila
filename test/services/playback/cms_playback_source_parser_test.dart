import 'package:flutter_test/flutter_test.dart';
import 'package:weila/services/playback/cms_playback_source_parser.dart';

void main() {
  const parser = CmsPlaybackSourceParser();

  test('keeps every CMS route and aligns equivalent episode titles', () {
    const playFrom = r'主线$$$备用';
    const playUrl = '第1集\$https://main/1.m3u8#第2集\$https://main/2.m3u8'
        r'$$$'
        '01\$https://backup/1.m3u8#02\$https://backup/2.m3u8';

    final episodes = parser.parse(
      playFrom: playFrom,
      playUrl: playUrl,
      headers: const {'Referer': 'https://site.example/'},
    );

    expect(episodes, hasLength(2));
    expect(episodes[0].name, '第1集');
    expect(episodes[0].index, 1);
    expect(episodes[0].sources.map((source) => source.id), ['cms-0', 'cms-1']);
    expect(episodes[0].sources.map((source) => source.label), ['主线', '备用']);
    expect(
      episodes[0].sources.map((source) => source.variants.single.url),
      ['https://main/1.m3u8', 'https://backup/1.m3u8'],
    );
    expect(
      episodes[1].sources.map((source) => source.variants.single.url),
      ['https://main/2.m3u8', 'https://backup/2.m3u8'],
    );
    expect(
      episodes[0].sources.every(
            (source) => source.headers['Referer'] == 'https://site.example/',
          ),
      isTrue,
    );
  });

  test('fills a missing route label and discards blank URLs', () {
    final episodes = parser.parse(
      playFrom: r'主线$$$',
      playUrl: '第1集\$#第2集\$https://main/2.mp4'
          r'$$$'
          '第1集\$https://backup/1.mp4#第2集\$https://backup/2.mp4',
      headers: const {},
    );

    expect(episodes, hasLength(2));
    expect(episodes[0].name, '第1集');
    expect(episodes[0].sources, hasLength(1));
    expect(episodes[0].sources.single.label, '线路 2');
    expect(episodes[1].sources.map((source) => source.label), ['主线', '线路 2']);
  });

  test('orders the first HLS route before earlier non-HLS routes', () {
    final episodes = parser.parse(
      playFrom: r'直链$$$流媒体$$$备用',
      playUrl: '第1集\$https://direct/1.mp4'
          r'$$$'
          '第1集\$https://hls/1.m3u8'
          r'$$$'
          '第1集\$https://backup/1.mp4',
      headers: const {},
    );

    expect(episodes, hasLength(1));
    expect(
      episodes.single.sources.map((source) => source.id),
      ['cms-1', 'cms-0', 'cms-2'],
    );
    expect(
      episodes.single.sources.map((source) => source.label),
      ['流媒体', '直链', '备用'],
    );
  });

  test('does not merge conflicting non-episode titles by ordinal alone', () {
    final episodes = parser.parse(
      playFrom: r'主线$$$备用',
      playUrl: '正片\$https://main/main.m3u8'
          r'$$$'
          '预告\$https://backup/trailer.m3u8',
      headers: const {},
    );

    expect(episodes, hasLength(2));
    expect(episodes.map((episode) => episode.name), ['正片', '预告']);
    expect(episodes.every((episode) => episode.sources.length == 1), isTrue);
  });
}
