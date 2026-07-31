import 'dart:io';

import 'package:package_info_plus/package_info_plus.dart';

import '../danmaku/danmaku_diagnostics.dart';
import '../playback/playback_diagnostics.dart';
import 'acceptance_report.dart';

typedef AcceptanceReportVersionLoader = Future<String> Function();
typedef AcceptanceReportClock = DateTime Function();

PlaybackDiagnosticsSnapshot? selectAcceptancePlaybackDiagnostics({
  required PlaybackDiagnosticsSnapshot? active,
  required PlaybackDiagnosticsSnapshot? lastCompleted,
}) =>
    active ?? lastCompleted;

class AcceptanceReportService {
  AcceptanceReportService({
    AcceptanceReportVersionLoader? loadAppVersion,
    AcceptanceReportClock? now,
    String? platform,
  })  : _loadAppVersion = loadAppVersion ?? _defaultVersionLoader,
        _now = now ?? DateTime.now,
        _platform = platform ?? Platform.operatingSystem;

  final AcceptanceReportVersionLoader _loadAppVersion;
  final AcceptanceReportClock _now;
  final String _platform;

  Future<AcceptanceReportV1> create({
    PlaybackAcceptanceData? playback,
    DanmakuDebugSnapshot? danmaku,
    RouteHealthAcceptanceData? routeHealth,
  }) async {
    String appVersion;
    try {
      appVersion = await _loadAppVersion();
    } catch (_) {
      appVersion = 'unknown';
    }
    return AcceptanceReportV1(
      generatedAtUtc: _now().toUtc(),
      appVersion: appVersion,
      platform: _platform,
      playback: playback,
      danmaku: danmaku,
      routeHealth: routeHealth,
    );
  }

  DanmakuDebugSnapshot combineDanmakuDiagnostics({
    required DanmakuLoadDiagnostics load,
    required DanmakuControllerDiagnostics controller,
  }) {
    final errorStage = load.errorStage != DanmakuErrorStage.none
        ? load.errorStage
        : controller.renderError == null
            ? DanmakuErrorStage.none
            : DanmakuErrorStage.render;
    return DanmakuDebugSnapshot(
      episodeId: load.episodeId,
      commentCount: load.commentCount,
      parsedCount: load.parsedCount,
      queuedCount: controller.queuedCount,
      currentTime: controller.currentTime,
      emittedCount: controller.emittedCount,
      renderedCount: controller.renderedCount,
      danmakuEnabled: controller.danmakuEnabled,
      opacity: controller.opacity,
      area: controller.area,
      errorStage: errorStage,
    );
  }

  static Future<String> _defaultVersionLoader() async {
    final info = await PackageInfo.fromPlatform();
    final build = info.buildNumber.trim();
    return build.isEmpty ? info.version : '${info.version}+$build';
  }
}
