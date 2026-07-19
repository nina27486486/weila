import 'package:flutter_test/flutter_test.dart';
import 'package:weila/models/playback/playback_source.dart';
import 'package:weila/services/playback/playback_auto_selector.dart';
import 'package:weila/services/playback/playback_probe_service.dart';
import 'package:weila/services/playback/playback_route_health.dart';

PlaybackSource _source(String id, {bool hasVariant = true}) {
  return PlaybackSource(
    id: id,
    label: id,
    kind: PlaybackSourceKind.cms,
    variants: hasVariant
        ? [
            PlaybackVariant(
              id: '$id-original',
              label: '原始',
              url: 'https://$id.example/video.m3u8',
              kind: PlaybackVariantKind.original,
            ),
          ]
        : const [],
  );
}

PlaybackRouteKey _key(String id) => PlaybackRouteKey(
      providerId: 'provider',
      sourceKind: 'cms',
      sourceId: id,
      host: '$id.example',
    );

PlaybackRouteHealth _health({
  required DateTime now,
  double successRate = .95,
  double firstFrameMs = 1500,
  double rebufferRatio = 0,
  DateTime? lastFailureAt,
}) {
  return PlaybackRouteHealth(
    samples: 4,
    successRate: successRate,
    firstFrameMs: firstFrameMs,
    rebufferRatio: rebufferRatio,
    probeSuccessRate: 1,
    updatedAt: now,
    lastFailureAt: lastFailureAt,
  );
}

PlaybackAutoCandidate _candidate(
  String id,
  int index, {
  PlaybackRouteHealth? health,
  PlaybackProbeResult? probe,
  bool hasVariant = true,
}) {
  return PlaybackAutoCandidate(
    source: _source(id, hasVariant: hasVariant),
    originalIndex: index,
    key: _key(id),
    health: health,
    probe: probe,
  );
}

void main() {
  const selector = PlaybackAutoSelector();
  final now = DateTime.utc(2026, 7, 11, 12);

  test('orders sufficient health samples by score', () {
    final ordered = selector.order([
      _candidate(
        'slow',
        0,
        health: _health(
          now: now,
          successRate: .7,
          firstFrameMs: 8000,
          rebufferRatio: .15,
        ),
      ),
      _candidate('stable', 1, health: _health(now: now)),
    ], now: now);

    expect(ordered.map((source) => source.id), ['stable', 'slow']);
  });

  test('keeps unknown candidates in original order', () {
    final ordered = selector.order([
      _candidate('second', 1),
      _candidate('first', 0),
      _candidate('third', 2),
    ], now: now);

    expect(ordered.map((source) => source.id), ['first', 'second', 'third']);
  });

  test('single successful probe does not outrank stable samples', () {
    final ordered = selector.order([
      _candidate(
        'unknown',
        0,
        probe: PlaybackProbeResult(
          success: true,
          elapsed: const Duration(milliseconds: 20),
          checkedAt: now,
        ),
      ),
      _candidate('stable', 1, health: _health(now: now)),
    ], now: now);

    expect(ordered.map((source) => source.id), ['stable', 'unknown']);
  });

  test('a currently reachable route outranks a currently failed route', () {
    final ordered = selector.order([
      _candidate(
        'failed-stable',
        0,
        health: _health(now: now),
        probe: PlaybackProbeResult(
          success: false,
          elapsed: const Duration(milliseconds: 20),
          checkedAt: now,
          failure: PlaybackProbeFailure.forbidden,
        ),
      ),
      _candidate(
        'reachable',
        1,
        probe: PlaybackProbeResult(
          success: true,
          elapsed: const Duration(milliseconds: 50),
          checkedAt: now,
        ),
      ),
    ], now: now);

    expect(ordered.map((source) => source.id), [
      'reachable',
      'failed-stable',
    ]);
  });

  test('uses original order for equal scores', () {
    final sameHealth = _health(now: now);
    final ordered = selector.order([
      _candidate('second', 1, health: sameHealth),
      _candidate('first', 0, health: sameHealth),
    ], now: now);

    expect(ordered.map((source) => source.id), ['first', 'second']);
  });

  test('recent failure lowers an otherwise equal route', () {
    final ordered = selector.order([
      _candidate(
        'recent-failure',
        0,
        health: _health(
          now: now,
          lastFailureAt: now.subtract(const Duration(minutes: 1)),
        ),
      ),
      _candidate('healthy', 1, health: _health(now: now)),
    ], now: now);

    expect(ordered.map((source) => source.id), ['healthy', 'recent-failure']);
  });

  test('removes sources without playable variants', () {
    final ordered = selector.order([
      _candidate('empty', 0, hasVariant: false),
      _candidate('playable', 1),
    ], now: now);

    expect(ordered.map((source) => source.id), ['playable']);
  });
}
