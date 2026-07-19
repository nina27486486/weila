import 'package:flutter_test/flutter_test.dart';
import 'package:weila/models/playback/playback_source.dart';
import 'package:weila/pages/player/playback_session.dart';

void main() {
  PlaybackSource source({
    required String id,
    required String label,
    required List<PlaybackVariant> variants,
    Map<String, String> headers = const {},
  }) {
    return PlaybackSource(
      id: id,
      label: label,
      kind: PlaybackSourceKind.cms,
      variants: variants,
      headers: headers,
    );
  }

  PlaybackVariant variant(String id) {
    return PlaybackVariant(
      id: id,
      label: id,
      url: 'https://cdn.example/$id.m3u8',
      kind: PlaybackVariantKind.original,
    );
  }

  late PlaybackSession session;

  setUp(() {
    session = PlaybackSession([
      source(
        id: 'primary',
        label: '主线',
        variants: [variant('primary-1'), variant('primary-2')],
      ),
      source(
        id: 'backup',
        label: '备用',
        headers: const {'Referer': 'https://site.example/'},
        variants: [variant('backup-1'), variant('backup-2')],
      ),
    ]);
  });

  test('drops sub-second resume positions', () {
    final request = session.openAt(const Duration(milliseconds: 900));

    expect(request, isNotNull);
    expect(request!.resumePosition, Duration.zero);
    expect(request.url, 'https://cdn.example/primary-1.m3u8');
  });

  test('manual source and quality switches keep a meaningful position', () {
    const position = Duration(minutes: 12, seconds: 34);

    final sourceRequest = session.selectSource('backup', position);
    final qualityRequest = session.selectVariant('backup-2', position);

    expect(sourceRequest!.variant.id, 'backup-1');
    expect(qualityRequest!.variant.id, 'backup-2');
    expect(qualityRequest.resumePosition, position);
    expect(qualityRequest.headers, {'Referer': 'https://site.example/'});
    expect(session.selection.sourceId, 'backup');
    expect(session.selection.variantId, 'backup-2');
  });

  test('selecting a different source resets its quality to default', () {
    session.selectVariant('primary-2', const Duration(seconds: 20));

    final request = session.selectSource('backup', const Duration(seconds: 20));

    expect(request!.variant.id, 'backup-1');
    expect(session.selection.sourceId, 'backup');
    expect(session.selection.variantId, isNull);
  });

  test('next variant stays within the selected source', () {
    session.selectSource('backup', Duration.zero);

    final next = session.selectNextVariant(const Duration(seconds: 30));
    final exhausted = session.selectNextVariant(const Duration(seconds: 30));

    expect(next!.source.id, 'backup');
    expect(next.variant.id, 'backup-2');
    expect(exhausted, isNull);
  });

  test('next source switches route and preserves resume position', () {
    const position = Duration(minutes: 3, seconds: 12);

    final next = session.selectNextSource(position);
    final exhausted = session.selectNextSource(position);

    expect(next, isNotNull);
    expect(next!.source.id, 'backup');
    expect(next.variant.id, 'backup-1');
    expect(next.resumePosition, position);
    expect(exhausted, isNull);
  });

  test('recovery starts at first route when active source predates hydration',
      () {
    final recovery = session.selectNextSourceAfter(
      'direct-before-hydration',
      const Duration(seconds: 9),
    );

    expect(recovery, isNotNull);
    expect(recovery!.source.id, 'primary');
    expect(recovery.resumePosition, const Duration(seconds: 9));
  });

  test('resolved source replacement preserves or safely resets selection', () {
    session.selectSource('primary', Duration.zero);
    session.selectVariant('primary-2', Duration.zero);
    session.replaceSource(
      source(
        id: 'primary',
        label: '主线',
        variants: [
          PlaybackVariant(
            id: 'primary-2',
            label: '720P',
            url: 'https://cdn.example/720.m3u8',
            kind: PlaybackVariantKind.hls,
          ),
          PlaybackVariant(
            id: 'primary-3',
            label: '1080P',
            url: 'https://cdn.example/1080.m3u8',
            kind: PlaybackVariantKind.hls,
          ),
        ],
      ),
    );

    expect(session.selection.variantId, 'primary-2');
    expect(session.openAt(Duration.zero)!.variant.label, '720P');

    session.replaceSource(
      source(
        id: 'primary',
        label: '主线',
        variants: [variant('replacement-default')],
      ),
    );

    expect(session.selection.sourceId, 'primary');
    expect(session.selection.variantId, isNull);
    expect(session.openAt(Duration.zero)!.variant.id, 'replacement-default');
  });

  test('invalid selections do not corrupt the active selection', () {
    final before = session.selection;

    expect(session.selectSource('missing', Duration.zero), isNull);
    expect(session.selectVariant('missing', Duration.zero), isNull);
    expect(session.selection.sourceId, before.sourceId);
    expect(session.selection.variantId, before.variantId);
  });

  test('auto source returns to the default route', () {
    session.selectSource('backup', Duration.zero);

    final request = session.selectAuto(const Duration(seconds: 12));

    expect(request!.source.id, 'primary');
    expect(request.variant.id, 'primary-1');
    expect(session.selection.sourceId, isNull);
    expect(session.selection.variantId, isNull);
  });

  test('auto quality keeps the current manual route', () {
    session.selectSource('backup', Duration.zero);
    session.selectVariant('backup-2', Duration.zero);

    final request = session.selectAutoVariant(const Duration(seconds: 12));

    expect(request!.source.id, 'backup');
    expect(request.variant.id, 'backup-1');
    expect(session.selection.sourceId, 'backup');
    expect(session.selection.variantId, isNull);
  });

  test('replacing source order changes auto route', () {
    session.replaceSources([
      session.sources[1],
      session.sources[0],
    ]);

    expect(session.openAt(Duration.zero)!.source.id, 'backup');
  });

  test('replacing source order preserves a valid manual route', () {
    session.selectSource('backup', Duration.zero);

    session.replaceSources([
      session.sources[1],
      session.sources[0],
    ]);

    expect(session.selection.sourceId, 'backup');
    expect(session.openAt(Duration.zero)!.source.id, 'backup');
  });
}
