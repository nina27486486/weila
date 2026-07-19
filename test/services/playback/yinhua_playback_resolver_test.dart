import 'package:flutter_test/flutter_test.dart';
import 'package:weila/models/playback/playback_source.dart';
import 'package:weila/services/playback/yinhua_playback_resolver.dart';

void main() {
  test('resolves a Yinhua website token into its current HLS manifest',
      () async {
    final requests = <Uri>[];
    final requestHeaders = <Map<String, String>>[];
    final resolver = YinhuaPlaybackResolver(
      loadHtml: (uri, headers) async {
        requests.add(uri);
        requestHeaders.add(Map<String, String>.from(headers));
        if (requests.length == 1) {
          return '''
            <script>
              var player_aaaa={"url":"MCZY-sample-token","from":"lzm3u8","sid":2,"nid":1}
            </script>
          ''';
        }
        return '''
          <meta charset="UTF-8" id="now_5036197482">
          <meta name="viewport" id="now_AYJjAenupn">
          <script>
            var config = {
              "url": "HfXIRfzcz8LllZowkotd0Kt1pWdT6EibHhsetDPQ49lEMXLMWMZ3zoVFfTr5hLg0EDGVnECmPNcQlO7dC6o/aQ=="
            }
          </script>
        ''';
      },
    );
    final source = PlaybackSource(
      id: 'cms-1',
      label: 'lzm3u8',
      kind: PlaybackSourceKind.cms,
      headers: const {
        'User-Agent': 'Weila test',
        'Referer': 'https://www.yinhuadm.xyz/',
      },
      variants: const [
        PlaybackVariant(
          id: 'cms-1-1',
          label: '原始',
          url: 'https://stale.example/episode.m3u8',
          kind: PlaybackVariantKind.original,
        ),
      ],
    );

    final resolvedEpisode = await resolver.resolveEpisode(
      baseUrl: Uri.parse('https://www.yinhuadm.xyz'),
      cmsId: '28572',
      episode: PlaybackEpisode(
        name: '第01集',
        index: 1,
        sources: [source],
      ),
    );
    final resolved = resolvedEpisode.sources.single;

    expect(requests, [
      Uri.parse('https://www.yinhuadm.xyz/p/28572-2-1.html'),
      Uri.parse(
        'https://player.mcue.cc/yinhua/?url=MCZY-sample-token',
      ),
    ]);
    expect(requestHeaders.first['User-Agent'], 'Weila test');
    expect(
      requestHeaders.last['Referer'],
      'https://www.yinhuadm.xyz/p/28572-2-1.html',
    );
    expect(resolved.id, source.id);
    expect(resolved.label, source.label);
    expect(resolvedEpisode.name, '第01集');
    expect(resolvedEpisode.index, 1);
    expect(resolved.headers, {'User-Agent': 'Weila test'});
    expect(resolved.variants.single.kind, PlaybackVariantKind.hls);
    expect(
      resolved.variants.single.url,
      'https://v.lzcdn27.com/20260405/8220_250cf3bb/index.m3u8',
    );
  });
}
