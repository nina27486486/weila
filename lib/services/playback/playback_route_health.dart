import 'playback_diagnostics.dart';
import 'playback_probe_service.dart';

class PlaybackRouteKey {
  const PlaybackRouteKey({
    required this.providerId,
    required this.sourceKind,
    required this.sourceId,
    required this.host,
  });

  final String providerId;
  final String sourceKind;
  final String sourceId;
  final String host;

  String get storageKey => [
        providerId.trim(),
        sourceKind.trim(),
        sourceId.trim(),
        host.trim().toLowerCase(),
      ].join('|');
}

class PlaybackRouteHealth {
  const PlaybackRouteHealth({
    required this.samples,
    required this.successRate,
    required this.firstFrameMs,
    required this.rebufferRatio,
    required this.probeSuccessRate,
    required this.updatedAt,
    this.lastFailureAt,
  });

  static const _newSampleWeight = .35;
  static const _failurePenalty = 20.0;
  static const _failureDecayWindow = Duration(days: 7);

  final int samples;
  final double successRate;
  final double firstFrameMs;
  final double rebufferRatio;
  final double probeSuccessRate;
  final DateTime updatedAt;
  final DateTime? lastFailureAt;

  bool get hasEnoughSamples => samples >= 2;

  double score(DateTime now) {
    final success = successRate.clamp(0.0, 1.0);
    final probe = probeSuccessRate.clamp(0.0, 1.0);
    final rebuffer = rebufferRatio.clamp(0.0, 1.0);
    final startup = switch (firstFrameMs) {
      <= 2000 => 1.0,
      >= 12000 => 0.0,
      _ => (12000 - firstFrameMs) / 10000,
    };
    final base = 50 * success +
        25 * startup.clamp(0.0, 1.0) +
        20 * (1 - rebuffer) +
        5 * probe;
    return (base - _recentFailurePenalty(now)).clamp(0.0, 100.0);
  }

  String get label {
    if (!hasEnoughSamples) return '未知';
    final value = score(updatedAt);
    if (value >= 80) return '良好';
    if (value >= 60) return '一般';
    return '不稳定';
  }

  PlaybackRouteHealth record({
    required PlaybackDiagnosticsSnapshot diagnostics,
    PlaybackProbeResult? probe,
    required Duration playedDuration,
    required DateTime now,
  }) {
    final succeeded =
        diagnostics.firstFrameRendered && diagnostics.failureKind == null;
    final firstFrameSample =
        diagnostics.firstFrameDuration?.inMilliseconds.toDouble() ?? 12000;
    final rebufferSample = playedDuration > Duration.zero
        ? diagnostics.totalRebufferDuration.inMicroseconds /
            playedDuration.inMicroseconds
        : succeeded
            ? 0.0
            : 1.0;
    final probeSample = probe == null
        ? probeSuccessRate
        : probe.success
            ? 1.0
            : 0.0;
    if (samples <= 0) {
      return PlaybackRouteHealth(
        samples: 1,
        successRate: succeeded ? 1 : 0,
        firstFrameMs: firstFrameSample,
        rebufferRatio: rebufferSample.clamp(0.0, 1.0),
        probeSuccessRate: probeSample.clamp(0.0, 1.0),
        updatedAt: now,
        lastFailureAt: succeeded ? null : now,
      );
    }
    return PlaybackRouteHealth(
      samples: samples + 1,
      successRate: _weighted(successRate, succeeded ? 1 : 0),
      firstFrameMs: _weighted(firstFrameMs, firstFrameSample),
      rebufferRatio: _weighted(
        rebufferRatio,
        rebufferSample.clamp(0.0, 1.0),
      ),
      probeSuccessRate: _weighted(
        probeSuccessRate,
        probeSample.clamp(0.0, 1.0),
      ),
      updatedAt: now,
      lastFailureAt: succeeded ? lastFailureAt : now,
    );
  }

  Map<String, dynamic> toMap() => {
        'samples': samples,
        'successRate': successRate,
        'firstFrameMs': firstFrameMs,
        'rebufferRatio': rebufferRatio,
        'probeSuccessRate': probeSuccessRate,
        'updatedAt': updatedAt.toUtc().toIso8601String(),
        if (lastFailureAt != null)
          'lastFailureAt': lastFailureAt!.toUtc().toIso8601String(),
      };

  static PlaybackRouteHealth? tryParse(Object? value) {
    if (value is! Map) return null;
    final samples = value['samples'];
    final successRate = value['successRate'];
    final firstFrameMs = value['firstFrameMs'];
    final rebufferRatio = value['rebufferRatio'];
    final probeSuccessRate = value['probeSuccessRate'];
    final updatedAt = DateTime.tryParse(value['updatedAt']?.toString() ?? '');
    final failureValue = value['lastFailureAt'];
    final lastFailureAt = failureValue == null
        ? null
        : DateTime.tryParse(failureValue.toString());
    if (samples is! int ||
        successRate is! num ||
        firstFrameMs is! num ||
        rebufferRatio is! num ||
        probeSuccessRate is! num ||
        updatedAt == null ||
        (failureValue != null && lastFailureAt == null)) {
      return null;
    }
    return PlaybackRouteHealth(
      samples: samples,
      successRate: successRate.toDouble(),
      firstFrameMs: firstFrameMs.toDouble(),
      rebufferRatio: rebufferRatio.toDouble(),
      probeSuccessRate: probeSuccessRate.toDouble(),
      updatedAt: updatedAt.toUtc(),
      lastFailureAt: lastFailureAt?.toUtc(),
    );
  }

  double _recentFailurePenalty(DateTime now) {
    final failedAt = lastFailureAt;
    if (failedAt == null) return 0;
    final age = now.toUtc().difference(failedAt.toUtc());
    if (age >= _failureDecayWindow) return 0;
    if (age <= Duration.zero) return _failurePenalty;
    final remaining =
        1 - age.inMicroseconds / _failureDecayWindow.inMicroseconds.toDouble();
    return _failurePenalty * remaining.clamp(0.0, 1.0);
  }

  static double _weighted(double previous, double sample) {
    return previous * (1 - _newSampleWeight) + sample * _newSampleWeight;
  }
}
