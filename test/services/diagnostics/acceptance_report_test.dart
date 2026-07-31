import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:weila/services/danmaku/danmaku_diagnostics.dart';
import 'package:weila/services/diagnostics/acceptance_report.dart';
import 'package:weila/services/playback/playback_diagnostics.dart';

void main() {
  test('serializes a complete versioned playback and danmaku report', () {
    final report = AcceptanceReportV1(
      generatedAtUtc: DateTime.utc(2026, 7, 23, 12, 30),
      appVersion: '1.0.0+5',
      platform: 'windows',
      playback: const PlaybackAcceptanceData(
        contentId: 'content-42',
        episodeIndex: 3,
        providerId: 'yinhua',
        sourceKind: 'cms',
        sourceId: 'route-2',
        variantId: 'hls-720p',
        mediaHost: 'media.example.com',
        stage: PlaybackDiagnosticStage.playing,
        firstFrameRendered: true,
        sourceResolveDuration: Duration(milliseconds: 250),
        manifestDuration: Duration(milliseconds: 400),
        openDuration: Duration(milliseconds: 700),
        firstFrameDuration: Duration(milliseconds: 1600),
        rebufferCount: 1,
        totalRebufferDuration: Duration(milliseconds: 800),
        longestRebufferDuration: Duration(milliseconds: 800),
        automaticRecoveryCount: 1,
        playedDuration: Duration(minutes: 2),
      ),
      danmaku: const DanmakuDebugSnapshot(
        episodeId: 24680,
        commentCount: 120,
        parsedCount: 118,
        queuedCount: 118,
        currentTime: 60.5,
        emittedCount: 21,
        renderedCount: 20,
        danmakuEnabled: true,
        opacity: .8,
        area: .5,
        errorStage: DanmakuErrorStage.none,
      ),
      routeHealth: RouteHealthAcceptanceData(
        samples: 4,
        successRate: .75,
        firstFrameMs: 2100,
        rebufferRatio: .02,
        probeSuccessRate: 1,
        score: 82.5,
        label: '良好',
      ),
    );

    final map = report.toSafeMap();
    final decoded = jsonDecode(report.toSafeJson()) as Map<String, dynamic>;

    expect(map['schemaVersion'], 1);
    expect(map['generatedAtUtc'], '2026-07-23T12:30:00.000Z');
    expect(decoded['appVersion'], '1.0.0+5');
    expect(decoded['platform'], 'windows');
    expect(
      (decoded['playback'] as Map<String, dynamic>)['firstFrameMs'],
      1600,
    );
    expect(
      (decoded['playback'] as Map<String, dynamic>)['stage'],
      'playing',
    );
    expect(
      (decoded['danmaku'] as Map<String, dynamic>)['renderedCount'],
      20,
    );
    expect(
      (decoded['routeHealth'] as Map<String, dynamic>)['score'],
      82.5,
    );
    expect(
      (decoded['routeHealth'] as Map<String, dynamic>)['label'],
      '良好',
    );
  });

  test('redacts unsafe identifiers and never exposes URLs or secrets', () {
    final report = AcceptanceReportV1(
      generatedAtUtc: DateTime.utc(2026, 7, 23),
      appVersion: '1.0.0',
      platform: 'windows',
      playback: const PlaybackAcceptanceData(
        contentId: r'C:\Users\nina\secret',
        episodeIndex: 0,
        providerId: 'provider',
        sourceKind: 'cms',
        sourceId: 'https://cdn.example/video.m3u8?token=super-secret',
        variantId: 'Authorization: Bearer super-secret',
        mediaHost: 'user:password@cdn.example.com',
        stage: PlaybackDiagnosticStage.failed,
        firstFrameRendered: false,
        rebufferCount: 0,
        totalRebufferDuration: Duration.zero,
        longestRebufferDuration: Duration.zero,
        automaticRecoveryCount: 0,
        playedDuration: Duration.zero,
        failureKind: PlaybackFailureKind.forbidden,
      ),
    );

    final json = report.toSafeJson();

    expect(json, isNot(contains('https://')));
    expect(json, isNot(contains('m3u8')));
    expect(json, isNot(contains('super-secret')));
    expect(json, isNot(contains('Authorization')));
    expect(json, isNot(contains(r'C:\Users')));
    expect(json, isNot(contains('password')));
    expect(json, contains('[redacted]'));
  });

  test('strictly allowlists identifiers and route health labels', () {
    final report = AcceptanceReportV1(
      generatedAtUtc: DateTime.utc(2026, 7, 30),
      appVersion: '1.0.0+5',
      platform: 'windows',
      playback: const PlaybackAcceptanceData(
        contentId: 'content-42',
        episodeIndex: 0,
        providerId: 'provider?api_key=credential-value',
        sourceKind: 'cms;cookie=session-value',
        sourceId: 'https%3A%2F%2Fcdn.example%2Fvideo',
        variantId: 'quality=1080p',
        mediaHost: 'cdn.example.com',
        stage: PlaybackDiagnosticStage.failed,
        firstFrameRendered: false,
        rebufferCount: 0,
        totalRebufferDuration: Duration.zero,
        longestRebufferDuration: Duration.zero,
        automaticRecoveryCount: 0,
        playedDuration: Duration.zero,
      ),
      routeHealth: const RouteHealthAcceptanceData(
        samples: 2,
        successRate: 1,
        firstFrameMs: 1200,
        rebufferRatio: 0,
        probeSuccessRate: 1,
        score: 95,
        label: '良好<script>',
      ),
    );

    final decoded = jsonDecode(report.toSafeJson()) as Map<String, dynamic>;
    final playback = decoded['playback'] as Map<String, dynamic>;
    final routeHealth = decoded['routeHealth'] as Map<String, dynamic>;
    final json = report.toSafeJson();

    expect(decoded['appVersion'], '1.0.0+5');
    expect(decoded['platform'], 'windows');
    expect(playback['contentId'], 'content-42');
    expect(playback['providerId'], '[redacted]');
    expect(playback['sourceKind'], '[redacted]');
    expect(playback['sourceId'], '[redacted]');
    expect(playback['variantId'], '[redacted]');
    expect(routeHealth['label'], '[redacted]');
    expect(json, isNot(contains('credential-value')));
    expect(json, isNot(contains('session-value')));
    expect(json, isNot(contains('%2F')));
    expect(json, isNot(contains('<script>')));
  });
}
