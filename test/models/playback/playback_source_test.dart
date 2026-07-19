import 'package:flutter_test/flutter_test.dart';
import 'package:weila/models/playback/playback_source.dart';

void main() {
  late List<PlaybackSource> sources;

  setUp(() {
    sources = [
      PlaybackSource(
        id: 'primary',
        label: '主线',
        kind: PlaybackSourceKind.cms,
        variants: const [
          PlaybackVariant(
            id: 'primary-original',
            label: '原始',
            url: 'https://cdn.example/master.m3u8',
            kind: PlaybackVariantKind.original,
          ),
        ],
      ),
      PlaybackSource(
        id: 'backup',
        label: '备用',
        kind: PlaybackSourceKind.cms,
        headers: const {'Referer': 'https://site.example/'},
        variants: const [
          PlaybackVariant(
            id: '1080p',
            label: '1080P',
            url: 'https://cdn.example/1080.m3u8',
            kind: PlaybackVariantKind.hls,
            width: 1920,
            height: 1080,
          ),
          PlaybackVariant(
            id: '720p',
            label: '720P',
            url: 'https://cdn.example/720.m3u8',
            kind: PlaybackVariantKind.hls,
            width: 1280,
            height: 720,
          ),
        ],
      ),
    ];
  });

  test('auto selects the first source and its first variant', () {
    final selected = const PlaybackSelection.auto().resolve(sources);

    expect(selected, isNotNull);
    expect(selected!.source.id, 'primary');
    expect(selected.variant.id, 'primary-original');
  });

  test('manual source selects that source default variant', () {
    final selected = const PlaybackSelection.source('backup').resolve(sources);

    expect(selected, isNotNull);
    expect(selected!.source.id, 'backup');
    expect(selected.variant.id, '1080p');
  });

  test('manual variant never falls back to a different source', () {
    final selected =
        const PlaybackSelection.variant('backup', '720p').resolve(sources);

    expect(selected, isNotNull);
    expect(selected!.source.id, 'backup');
    expect(selected.variant.url, 'https://cdn.example/720.m3u8');
    expect(
      const PlaybackSelection.variant('missing', '720p').resolve(sources),
      isNull,
    );
    expect(
      const PlaybackSelection.variant('backup', 'missing').resolve(sources),
      isNull,
    );
  });

  test('empty sources and sources without variants cannot resolve', () {
    expect(const PlaybackSelection.auto().resolve(const []), isNull);
    expect(
      const PlaybackSelection.auto().resolve([
        PlaybackSource(
          id: 'empty',
          label: '空线路',
          kind: PlaybackSourceKind.direct,
          variants: [],
        ),
      ]),
      isNull,
    );
  });

  test('source collections are defensive and unmodifiable', () {
    final variants = <PlaybackVariant>[
      const PlaybackVariant(
        id: 'raw',
        label: '原始',
        url: 'https://cdn.example/raw.m3u8',
        kind: PlaybackVariantKind.original,
      ),
    ];
    final headers = <String, String>{'Referer': 'https://site.example/'};
    final source = PlaybackSource(
      id: 'source',
      label: '线路',
      kind: PlaybackSourceKind.direct,
      variants: variants,
      headers: headers,
    );

    variants.clear();
    headers.clear();

    expect(source.variants, hasLength(1));
    expect(source.headers['Referer'], 'https://site.example/');
    expect(() => source.variants.clear(), throwsUnsupportedError);
    expect(() => source.headers.clear(), throwsUnsupportedError);
  });
}
