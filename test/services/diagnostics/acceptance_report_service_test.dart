import 'package:flutter_test/flutter_test.dart';
import 'package:weila/services/danmaku/danmaku_diagnostics.dart';
import 'package:weila/services/diagnostics/acceptance_report_service.dart';
import 'package:weila/services/playback/playback_diagnostics.dart';

void main() {
  test('collects runtime metadata around a danmaku snapshot', () async {
    final service = AcceptanceReportService(
      loadAppVersion: () async => '1.0.0+5',
      now: () => DateTime.utc(2026, 7, 23, 15),
      platform: 'windows',
    );

    final report = await service.create(
      danmaku: const DanmakuDebugSnapshot(
        episodeId: 99,
        commentCount: 10,
        parsedCount: 9,
        queuedCount: 9,
        currentTime: 12.5,
        emittedCount: 4,
        renderedCount: 4,
        danmakuEnabled: true,
        opacity: .7,
        area: .5,
        errorStage: DanmakuErrorStage.none,
      ),
    );

    expect(report.generatedAtUtc, DateTime.utc(2026, 7, 23, 15));
    expect(report.appVersion, '1.0.0+5');
    expect(report.platform, 'windows');
    expect(report.danmaku?.episodeId, 99);
  });

  test('uses an explicit safe fallback when package metadata fails', () async {
    final service = AcceptanceReportService(
      loadAppVersion: () async => throw StateError('plugin unavailable'),
      now: () => DateTime.utc(2026),
      platform: 'windows',
    );

    final report = await service.create();

    expect(report.appVersion, 'unknown');
  });

  test('combines acquisition and render diagnostics without losing errors', () {
    final service = AcceptanceReportService(
      loadAppVersion: () async => '1.0.0',
      platform: 'windows',
    );

    final snapshot = service.combineDanmakuDiagnostics(
      load: const DanmakuLoadDiagnostics(
        episodeId: 88,
        commentCount: 15,
        parsedCount: 14,
      ),
      controller: const DanmakuControllerDiagnostics(
        queuedCount: 14,
        emittedCount: 5,
        renderedCount: 4,
        currentTime: 30,
        danmakuEnabled: true,
        opacity: .8,
        area: .5,
        renderError: 'layout failed',
      ),
    );

    expect(snapshot.episodeId, 88);
    expect(snapshot.queuedCount, 14);
    expect(snapshot.renderedCount, 4);
    expect(snapshot.errorStage, DanmakuErrorStage.render);
  });

  test('prefers the active playback diagnostics snapshot', () {
    final active = _playbackSnapshot(2);
    final completed = _playbackSnapshot(1);

    expect(
      selectAcceptancePlaybackDiagnostics(
        active: active,
        lastCompleted: completed,
      ),
      same(active),
    );
  });

  test('falls back to the last completed playback diagnostics snapshot', () {
    final completed = _playbackSnapshot(1);

    expect(
      selectAcceptancePlaybackDiagnostics(
        active: null,
        lastCompleted: completed,
      ),
      same(completed),
    );
  });
}

PlaybackDiagnosticsSnapshot _playbackSnapshot(int generation) {
  return PlaybackDiagnosticsSnapshot(
    openGeneration: generation,
    firstFrameRendered: true,
    rebufferCount: 0,
    totalRebufferDuration: Duration.zero,
    longestRebufferDuration: Duration.zero,
    stage: PlaybackDiagnosticStage.playing,
  );
}
