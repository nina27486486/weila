import 'package:flutter_test/flutter_test.dart';
import 'package:weila/services/playback/playback_diagnostics.dart';

void main() {
  test('records source manifest open and first-frame durations', () {
    var now = DateTime.utc(2026, 7, 11, 12);
    final session = PlaybackDiagnosticsSession(
      openGeneration: 7,
      now: () => now,
    );

    session.sourceResolveStarted();
    now = now.add(const Duration(milliseconds: 400));
    session.sourceResolved();
    session.manifestStarted();
    now = now.add(const Duration(milliseconds: 600));
    session.manifestResolved();
    session.openRequested();
    now = now.add(const Duration(seconds: 2));
    session.openCompleted();
    now = now.add(const Duration(seconds: 1));
    session.firstFrameRendered();

    final snapshot = session.snapshot;
    expect(snapshot.openGeneration, 7);
    expect(snapshot.sourceResolveDuration, const Duration(milliseconds: 400));
    expect(snapshot.manifestDuration, const Duration(milliseconds: 600));
    expect(snapshot.openDuration, const Duration(seconds: 2));
    expect(snapshot.firstFrameDuration, const Duration(seconds: 3));
    expect(snapshot.firstFrameRendered, isTrue);
  });

  test('ignores startup buffering and post-frame stalls below 300 ms', () {
    var now = DateTime.utc(2026, 7, 11, 12);
    final session = PlaybackDiagnosticsSession(
      openGeneration: 1,
      now: () => now,
    );

    session.bufferingChanged(true);
    now = now.add(const Duration(seconds: 2));
    session.bufferingChanged(false);
    session.openRequested();
    session.firstFrameRendered();
    session.bufferingChanged(true);
    now = now.add(const Duration(milliseconds: 299));
    session.bufferingChanged(false);

    expect(session.snapshot.rebufferCount, 0);
    expect(session.snapshot.totalRebufferDuration, Duration.zero);
    expect(session.snapshot.longestRebufferDuration, Duration.zero);
  });

  test('counts post-frame stalls at the threshold and tracks longest', () {
    var now = DateTime.utc(2026, 7, 11, 12);
    final session = PlaybackDiagnosticsSession(
      openGeneration: 2,
      now: () => now,
    )
      ..openRequested()
      ..firstFrameRendered();

    session.bufferingChanged(true);
    now = now.add(const Duration(milliseconds: 300));
    session.bufferingChanged(false);
    session.bufferingChanged(true);
    now = now.add(const Duration(milliseconds: 900));
    session.bufferingChanged(false);

    expect(session.snapshot.rebufferCount, 2);
    expect(
      session.snapshot.totalRebufferDuration,
      const Duration(milliseconds: 1200),
    );
    expect(
      session.snapshot.longestRebufferDuration,
      const Duration(milliseconds: 900),
    );
  });

  test('keeps first failure and end closes an active rebuffer once', () {
    var now = DateTime.utc(2026, 7, 11, 12);
    final session = PlaybackDiagnosticsSession(
      openGeneration: 3,
      now: () => now,
    )
      ..openRequested()
      ..firstFrameRendered()
      ..bufferingChanged(true);

    now = now.add(const Duration(milliseconds: 450));
    session.fail(PlaybackFailureKind.timeout);
    session.fail(PlaybackFailureKind.decode);
    final ended = session.end();
    final endedAgain = session.end();

    expect(ended.failureKind, PlaybackFailureKind.timeout);
    expect(ended.rebufferCount, 1);
    expect(ended.totalRebufferDuration, const Duration(milliseconds: 450));
    expect(endedAgain.rebufferCount, 1);
    expect(endedAgain.totalRebufferDuration, const Duration(milliseconds: 450));
  });

  test('moves through loading stages and exposes terminal state', () {
    final session = PlaybackDiagnosticsSession(openGeneration: 4);

    expect(session.snapshot.stage, PlaybackDiagnosticStage.idle);
    session.sourceResolveStarted();
    expect(session.snapshot.stage, PlaybackDiagnosticStage.resolvingSource);
    session.sourceResolved();
    session.manifestStarted();
    expect(session.snapshot.stage, PlaybackDiagnosticStage.resolvingManifest);
    session.manifestResolved();
    session.openRequested();
    expect(session.snapshot.stage, PlaybackDiagnosticStage.opening);
    session.openCompleted();
    expect(
        session.snapshot.stage, PlaybackDiagnosticStage.waitingForFirstFrame);
    session.firstFrameRendered();
    expect(session.snapshot.stage, PlaybackDiagnosticStage.playing);
    session.fail(PlaybackFailureKind.network);
    expect(session.snapshot.stage, PlaybackDiagnosticStage.failed);
    session.end();
    expect(session.snapshot.stage, PlaybackDiagnosticStage.ended);
  });

  test('suspending buffering discards an active lifecycle stall', () {
    var now = DateTime.utc(2026, 7, 11, 12);
    final session = PlaybackDiagnosticsSession(
      openGeneration: 5,
      now: () => now,
    )
      ..openRequested()
      ..firstFrameRendered()
      ..bufferingChanged(true);

    now = now.add(const Duration(seconds: 2));
    session.suspendBuffering();
    session.bufferingChanged(false);

    expect(session.snapshot.rebufferCount, 0);
    expect(session.snapshot.totalRebufferDuration, Duration.zero);
  });
}
