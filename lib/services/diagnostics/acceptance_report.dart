import 'dart:convert';

import '../danmaku/danmaku_diagnostics.dart';
import '../playback/playback_diagnostics.dart';

class AcceptanceReportV1 {
  const AcceptanceReportV1({
    required this.generatedAtUtc,
    required this.appVersion,
    required this.platform,
    this.playback,
    this.danmaku,
    this.routeHealth,
  });

  static const schemaVersion = 1;

  final DateTime generatedAtUtc;
  final String appVersion;
  final String platform;
  final PlaybackAcceptanceData? playback;
  final DanmakuDebugSnapshot? danmaku;
  final RouteHealthAcceptanceData? routeHealth;

  Map<String, Object?> toSafeMap() => <String, Object?>{
        'schemaVersion': schemaVersion,
        'generatedAtUtc': generatedAtUtc.toUtc().toIso8601String(),
        'appVersion': _safeToken(appVersion),
        'platform': _safeToken(platform),
        if (playback case final value?) 'playback': value.toSafeMap(),
        if (danmaku case final value?) 'danmaku': _danmakuMap(value),
        if (routeHealth case final value?) 'routeHealth': value.toSafeMap(),
      };

  String toSafeJson() =>
      const JsonEncoder.withIndent('  ').convert(toSafeMap());

  static Map<String, Object?> _danmakuMap(DanmakuDebugSnapshot value) =>
      <String, Object?>{
        'episodeId': value.episodeId,
        'commentCount': value.commentCount,
        'parsedCount': value.parsedCount,
        'queuedCount': value.queuedCount,
        'currentTime': value.currentTime,
        'emittedCount': value.emittedCount,
        'renderedCount': value.renderedCount,
        'danmakuEnabled': value.danmakuEnabled,
        'opacity': value.opacity,
        'area': value.area,
        'errorStage': value.errorStage.name,
      };
}

class PlaybackAcceptanceData {
  const PlaybackAcceptanceData({
    this.contentId,
    required this.episodeIndex,
    required this.providerId,
    required this.sourceKind,
    required this.sourceId,
    required this.variantId,
    required this.mediaHost,
    required this.stage,
    required this.firstFrameRendered,
    this.sourceResolveDuration,
    this.manifestDuration,
    this.openDuration,
    this.firstFrameDuration,
    required this.rebufferCount,
    required this.totalRebufferDuration,
    required this.longestRebufferDuration,
    required this.automaticRecoveryCount,
    required this.playedDuration,
    this.failureKind,
  });

  final String? contentId;
  final int episodeIndex;
  final String providerId;
  final String sourceKind;
  final String sourceId;
  final String variantId;
  final String mediaHost;
  final PlaybackDiagnosticStage stage;
  final bool firstFrameRendered;
  final Duration? sourceResolveDuration;
  final Duration? manifestDuration;
  final Duration? openDuration;
  final Duration? firstFrameDuration;
  final int rebufferCount;
  final Duration totalRebufferDuration;
  final Duration longestRebufferDuration;
  final int automaticRecoveryCount;
  final Duration playedDuration;
  final PlaybackFailureKind? failureKind;

  Map<String, Object?> toSafeMap() => <String, Object?>{
        if (contentId case final value?) 'contentId': _safeToken(value),
        'episodeIndex': episodeIndex,
        'providerId': _safeToken(providerId),
        'sourceKind': _safeToken(sourceKind),
        'sourceId': _safeToken(sourceId),
        'variantId': _safeToken(variantId),
        'mediaHost': _safeHost(mediaHost),
        'stage': stage.name,
        'firstFrameRendered': firstFrameRendered,
        if (sourceResolveDuration case final value?)
          'sourceResolveMs': value.inMilliseconds,
        if (manifestDuration case final value?)
          'manifestMs': value.inMilliseconds,
        if (openDuration case final value?) 'openMs': value.inMilliseconds,
        if (firstFrameDuration case final value?)
          'firstFrameMs': value.inMilliseconds,
        'rebufferCount': rebufferCount,
        'totalRebufferMs': totalRebufferDuration.inMilliseconds,
        'longestRebufferMs': longestRebufferDuration.inMilliseconds,
        'automaticRecoveryCount': automaticRecoveryCount,
        'playedDurationMs': playedDuration.inMilliseconds,
        if (failureKind case final value?) 'failureKind': value.name,
      };
}

class RouteHealthAcceptanceData {
  const RouteHealthAcceptanceData({
    required this.samples,
    required this.successRate,
    required this.firstFrameMs,
    required this.rebufferRatio,
    required this.probeSuccessRate,
    required this.score,
    required this.label,
  });

  final int samples;
  final double successRate;
  final double firstFrameMs;
  final double rebufferRatio;
  final double probeSuccessRate;
  final double score;
  final String label;

  Map<String, Object?> toSafeMap() => <String, Object?>{
        'samples': samples,
        'successRate': successRate,
        'firstFrameMs': firstFrameMs,
        'rebufferRatio': rebufferRatio,
        'probeSuccessRate': probeSuccessRate,
        'score': score,
        'label': _safeRouteHealthLabel(label),
      };
}

final RegExp _safeTokenPattern = RegExp(r'^[A-Za-z0-9._+-]+$');

String _safeToken(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return '';
  if (trimmed.length > 120 || !_safeTokenPattern.hasMatch(trimmed)) {
    return '[redacted]';
  }
  return trimmed;
}

String _safeRouteHealthLabel(String value) {
  final trimmed = value.trim();
  const allowed = {'未知', '良好', '一般', '不稳定'};
  return allowed.contains(trimmed) ? trimmed : '[redacted]';
}

String _safeHost(String value) {
  final trimmed = value.trim().toLowerCase();
  if (RegExp(r'^[a-z0-9.-]+$').hasMatch(trimmed)) return trimmed;
  return '[redacted]';
}
