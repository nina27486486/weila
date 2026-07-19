import 'package:flutter_test/flutter_test.dart';
import 'package:weila/services/playback/hls_master_playlist_parser.dart';

void main() {
  const parser = HlsMasterPlaylistParser();
  final manifestUri = Uri.parse('https://media.example/master.m3u8');

  test('parses resolution variants and resolves relative URLs', () {
    const body = '''
#EXTM3U
#EXT-X-STREAM-INF:BANDWIDTH=2800000,RESOLUTION=1920x1080
1080/index.m3u8
#EXT-X-STREAM-INF:AVERAGE-BANDWIDTH=1200000,RESOLUTION=1280x720
https://media.example/720/index.m3u8
''';

    final variants = parser.parse(manifestUri: manifestUri, body: body);

    expect(variants, hasLength(2));
    expect(variants.map((variant) => variant.label), ['1080P', '720P']);
    expect(variants[0].url, 'https://media.example/1080/index.m3u8');
    expect(variants[1].url, 'https://media.example/720/index.m3u8');
    expect(variants[0].width, 1920);
    expect(variants[0].height, 1080);
    expect(variants[0].bitrate, 2800000);
    expect(variants[1].bitrate, 1200000);
  });

  test('uses a bitrate label when resolution is absent', () {
    const body = '''
#EXTM3U
#EXT-X-STREAM-INF:BANDWIDTH=800000
low/index.m3u8
''';

    final variants = parser.parse(manifestUri: manifestUri, body: body);

    expect(variants.single.label, '码率 800 kbps');
    expect(variants.single.bitrate, 800000);
  });

  test('returns no variants for a media playlist', () {
    const body = '''
#EXTM3U
#EXT-X-TARGETDURATION:6
#EXTINF:6.0,
segment-1.ts
''';

    expect(parser.parse(manifestUri: manifestUri, body: body), isEmpty);
  });

  test('ignores malformed attributes without throwing', () {
    const body = '''
#EXTM3U
#EXT-X-STREAM-INF:BANDWIDTH=fast,RESOLUTION=broken
fallback/index.m3u8
''';

    final variants = parser.parse(manifestUri: manifestUri, body: body);

    expect(variants, hasLength(1));
    expect(variants.single.label, '原始');
    expect(variants.single.width, isNull);
    expect(variants.single.bitrate, isNull);
  });
}
