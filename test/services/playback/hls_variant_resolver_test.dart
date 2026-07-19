import 'package:flutter_test/flutter_test.dart';
import 'package:weila/models/playback/playback_source.dart';
import 'package:weila/services/playback/hls_variant_resolver.dart';

void main() {
  PlaybackSource buildSource(
      {String url = 'https://media.example/master.m3u8'}) {
    return PlaybackSource(
      id: 'cms-0',
      label: '主线',
      kind: PlaybackSourceKind.cms,
      headers: const {'Referer': 'https://site.example/'},
      variants: [
        PlaybackVariant(
          id: 'cms-0-1',
          label: '原始',
          url: url,
          kind: PlaybackVariantKind.original,
        ),
      ],
    );
  }

  test('loads a master playlist with source headers and expands variants',
      () async {
    Uri? loadedUri;
    Map<String, String>? loadedHeaders;
    final resolver = HlsVariantResolver(
      loadManifest: (uri, headers) async {
        loadedUri = uri;
        loadedHeaders = headers;
        return '''
#EXTM3U
#EXT-X-STREAM-INF:BANDWIDTH=2800000,RESOLUTION=1920x1080
1080/index.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=1200000,RESOLUTION=1280x720
720/index.m3u8
''';
      },
    );
    final source = buildSource();

    final resolved = await resolver.resolve(source);

    expect(loadedUri, Uri.parse('https://media.example/master.m3u8'));
    expect(loadedHeaders, {'Referer': 'https://site.example/'});
    expect(resolved.id, source.id);
    expect(resolved.label, source.label);
    expect(resolved.kind, source.kind);
    expect(resolved.headers, source.headers);
    expect(
        resolved.variants.map((variant) => variant.label), ['1080P', '720P']);
  });

  test('keeps the original source when loading fails', () async {
    final source = buildSource();
    final resolver = HlsVariantResolver(
      loadManifest: (_, __) async => throw StateError('network failed'),
    );

    expect(await resolver.resolve(source), same(source));
  });

  test('keeps the original source for a media playlist', () async {
    final source = buildSource();
    final resolver = HlsVariantResolver(
      loadManifest: (_, __) async => '''
#EXTM3U
#EXT-X-TARGETDURATION:6
#EXTINF:6.0,
segment-1.ts
''',
    );

    expect(await resolver.resolve(source), same(source));
  });

  test('does not load non-http variants', () async {
    var calls = 0;
    final source = buildSource(url: r'C:\videos\episode.mp4');
    final resolver = HlsVariantResolver(
      loadManifest: (_, __) async {
        calls++;
        return '';
      },
    );

    expect(await resolver.resolve(source), same(source));
    expect(calls, 0);
  });

  test('does not fetch an HTTP MP4 as a manifest', () async {
    var calls = 0;
    final source = buildSource(url: 'https://media.example/episode.mp4');
    final resolver = HlsVariantResolver(
      loadManifest: (_, __) async {
        calls++;
        return '';
      },
    );

    expect(await resolver.resolve(source), same(source));
    expect(calls, 0);
  });
}
