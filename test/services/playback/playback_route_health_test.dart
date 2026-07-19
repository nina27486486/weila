import 'package:flutter_test/flutter_test.dart';
import 'package:weila/services/playback/playback_diagnostics.dart';
import 'package:weila/services/playback/playback_probe_service.dart';
import 'package:weila/services/playback/playback_route_health.dart';

PlaybackRouteHealth _health({
  int samples = 3,
  double successRate = 1,
  double firstFrameMs = 1500,
  double rebufferRatio = 0,
  double probeSuccessRate = 1,
  DateTime? updatedAt,
  DateTime? lastFailureAt,
}) {
  return PlaybackRouteHealth(
    samples: samples,
    successRate: successRate,
    firstFrameMs: firstFrameMs,
    rebufferRatio: rebufferRatio,
    probeSuccessRate: probeSuccessRate,
    updatedAt: updatedAt ?? DateTime.utc(2026, 7, 11),
    lastFailureAt: lastFailureAt,
  );
}

void main() {
  test('requires two real samples before exposing a health label', () {
    expect(_health(samples: 0).hasEnoughSamples, isFalse);
    expect(_health(samples: 1).label, '未知');
    expect(_health(samples: 2).hasEnoughSamples, isTrue);
  });

  test('scores stable fast routes above slow rebuffering routes', () {
    final now = DateTime.utc(2026, 7, 11, 12);
    final stable = _health(
      successRate: .95,
      firstFrameMs: 1500,
      rebufferRatio: 0,
    );
    final unstable = _health(
      successRate: .7,
      firstFrameMs: 8000,
      rebufferRatio: .1,
      probeSuccessRate: .5,
    );

    expect(stable.score(now), greaterThan(unstable.score(now)));
    expect(stable.label, '良好');
    expect(unstable.label, '一般');
    expect(
      _health(
        successRate: .5,
        firstFrameMs: 12000,
        rebufferRatio: .5,
        probeSuccessRate: 0,
      ).label,
      '不稳定',
    );
  });

  test('clamps scores and decays recent failure penalty', () {
    final now = DateTime.utc(2026, 7, 11, 12);
    final recent =
        _health(lastFailureAt: now.subtract(const Duration(minutes: 1)));
    final old = _health(lastFailureAt: now.subtract(const Duration(days: 10)));
    final malformedRatios = _health(
      successRate: 4,
      firstFrameMs: -100,
      rebufferRatio: -2,
      probeSuccessRate: 3,
    );

    expect(recent.score(now), lessThan(old.score(now)));
    expect(malformedRatios.score(now), inInclusiveRange(0, 100));
  });

  test('records a new sample with 0.35 exponential weight', () {
    final now = DateTime.utc(2026, 7, 11, 12);
    final current = _health(
      samples: 4,
      successRate: .5,
      firstFrameMs: 8000,
      rebufferRatio: .2,
      probeSuccessRate: .5,
    );
    const diagnostics = PlaybackDiagnosticsSnapshot(
      openGeneration: 9,
      firstFrameRendered: true,
      rebufferCount: 1,
      totalRebufferDuration: Duration(seconds: 5),
      longestRebufferDuration: Duration(seconds: 5),
      firstFrameDuration: Duration(seconds: 2),
    );
    final recorded = current.record(
      diagnostics: diagnostics,
      probe: PlaybackProbeResult(
        success: true,
        elapsed: const Duration(milliseconds: 80),
        checkedAt: now,
      ),
      playedDuration: const Duration(seconds: 100),
      now: now,
    );

    expect(recorded.samples, 5);
    expect(recorded.successRate, closeTo(.675, .0001));
    expect(recorded.firstFrameMs, closeTo(5900, .0001));
    expect(recorded.rebufferRatio, closeTo(.1475, .0001));
    expect(recorded.probeSuccessRate, closeTo(.675, .0001));
    expect(recorded.lastFailureAt, isNull);
    expect(recorded.updatedAt, now);
  });

  test('records failure time and round-trips safe storage maps', () {
    final now = DateTime.utc(2026, 7, 11, 12);
    final failed = _health().record(
      diagnostics: const PlaybackDiagnosticsSnapshot(
        openGeneration: 10,
        firstFrameRendered: false,
        rebufferCount: 0,
        totalRebufferDuration: Duration.zero,
        longestRebufferDuration: Duration.zero,
        failureKind: PlaybackFailureKind.forbidden,
      ),
      playedDuration: Duration.zero,
      now: now,
    );
    final parsed = PlaybackRouteHealth.tryParse(failed.toMap());

    expect(failed.lastFailureAt, now);
    expect(parsed, isNotNull);
    expect(parsed!.samples, failed.samples);
    expect(parsed.lastFailureAt, now);
    expect(PlaybackRouteHealth.tryParse({'samples': 'bad'}), isNull);
  });

  test('route storage key uses stable source identity without URL data', () {
    const key = PlaybackRouteKey(
      providerId: 'cms-provider',
      sourceKind: 'cms',
      sourceId: 'main',
      host: 'media.example',
    );

    expect(key.storageKey, 'cms-provider|cms|main|media.example');
    expect(key.storageKey, isNot(contains('http')));
    expect(key.storageKey, isNot(contains('?')));
  });
}
