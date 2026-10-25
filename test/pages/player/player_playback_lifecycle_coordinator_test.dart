import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:weila/pages/player/player_playback_lifecycle_coordinator.dart';
import 'package:weila/services/playback/playback_diagnostics.dart';

void main() {
  void recordMediaEvidence(
    PlayerPlaybackLifecycleCoordinator coordinator,
    int generation,
  ) {
    coordinator.recordVideoMetadata(
      generation: generation,
      width: 640,
      height: 360,
    );
    coordinator.recordPlaybackPosition(
      generation: generation,
      position: const Duration(seconds: 1),
    );
  }

  test('Android metadata and progress cannot replace configured video output',
      () async {
    final coordinator = PlayerPlaybackLifecycleCoordinator(
      readVideoOutputConfigured: () async => false,
    );
    addTearDown(coordinator.dispose);
    final generation = coordinator.nextOpenGeneration();

    recordMediaEvidence(coordinator, generation);
    await Future<void>.delayed(Duration.zero);

    expect(coordinator.firstFrameEvidenceReady, isFalse);
  });

  test('Android waits for output configuration and retries transient false',
      () async {
    var configured = false;
    final coordinator = PlayerPlaybackLifecycleCoordinator(
      readVideoOutputConfigured: () async => configured,
    );
    addTearDown(coordinator.dispose);
    final generation = coordinator.nextOpenGeneration();
    recordMediaEvidence(coordinator, generation);
    await Future<void>.delayed(Duration.zero);
    expect(coordinator.firstFrameEvidenceReady, isFalse);

    configured = true;
    recordMediaEvidence(coordinator, generation);
    await coordinator.waitForFirstFrameEvidence(generation);
    expect(coordinator.firstFrameEvidenceReady, isTrue);
  });

  test(
      'final renderer failure releases waiters without recording a first frame',
      () async {
    final output = Completer<bool>();
    var queries = 0;
    final coordinator = PlayerPlaybackLifecycleCoordinator(
      readVideoOutputConfigured: () =>
          ++queries == 1 ? output.future : Future.value(false),
    );
    addTearDown(coordinator.dispose);
    final generation = coordinator.nextOpenGeneration();
    final diagnostics = PlaybackDiagnosticsSession(openGeneration: generation);
    diagnostics.openRequested();
    recordMediaEvidence(coordinator, generation);
    final wait = coordinator.waitForFirstFrameEvidence(generation);

    expect(
      await coordinator.recordVideoOutputLog(
        generation: generation,
        prefix: 'vo/gpu',
        level: 'error',
        text: 'Failed initializing any suitable GPU context!',
      ),
      isTrue,
    );
    diagnostics.fail(PlaybackFailureKind.noVideo);
    await wait;
    output.complete(true);
    await Future<void>.delayed(Duration.zero);
    recordMediaEvidence(coordinator, generation);
    if (coordinator.firstFrameEvidenceReady) diagnostics.firstFrameRendered();

    expect(coordinator.videoOutputFailed, isTrue);
    expect(coordinator.firstFrameEvidenceReady, isFalse);
    final snapshot = diagnostics.end();
    expect(snapshot.firstFrameRendered, isFalse);
    expect(snapshot.firstFrameDuration, isNull);
    expect(snapshot.failureKind, PlaybackFailureKind.noVideo);
    expect(snapshot.stage, PlaybackDiagnosticStage.failed);
  });

  test('renderer failure cancels pending recovery and reports once', () async {
    final coordinator = PlayerPlaybackLifecycleCoordinator(
      readVideoOutputConfigured: () async => false,
      reconnectDelay: const Duration(milliseconds: 10),
    );
    addTearDown(coordinator.dispose);
    final generation = coordinator.nextOpenGeneration();
    var retries = 0;
    coordinator.scheduleReconnect(
      generation: generation,
      action: () => retries++,
    );
    for (var attempt = 0; attempt < 2; attempt++) {
      expect(
        await coordinator.recordVideoOutputLog(
          generation: generation,
          prefix: 'cplayer',
          level: 'fatal',
          text:
              'Error opening/initializing the selected video_out (--vo) device.',
        ),
        attempt == 0,
      );
    }
    await Future<void>.delayed(const Duration(milliseconds: 25));
    expect(retries, 0);
  });

  test('decoder fallback and non-final GL errors are not renderer failure',
      () async {
    final coordinator = PlayerPlaybackLifecycleCoordinator(
      readVideoOutputConfigured: () async => false,
    );
    addTearDown(coordinator.dispose);
    final generation = coordinator.nextOpenGeneration();
    for (final log in [
      (
        'vo/gpu/opengl',
        'fatal',
        'Could not create EGL context for GLES 2.x +!'
      ),
      ('vd', 'error', 'Failed to initialize a hardware decoder'),
      ('vo/gpu', 'warn', 'Failed initializing any suitable GPU context!'),
      ('ffmpeg', 'error', 'Failed initializing any suitable GPU context!'),
      ('cplayer', 'error', 'HTTP error 403 Forbidden'),
    ]) {
      expect(
        await coordinator.recordVideoOutputLog(
          generation: generation,
          prefix: log.$1,
          level: log.$2,
          text: log.$3,
        ),
        isFalse,
      );
    }
    expect(coordinator.videoOutputFailed, isFalse);
  });

  test('stale output queries and errors cannot affect a new generation',
      () async {
    final oldOutput = Completer<bool>();
    var calls = 0;
    final coordinator = PlayerPlaybackLifecycleCoordinator(
      readVideoOutputConfigured: () {
        calls++;
        return calls == 1 ? oldOutput.future : Future.value(false);
      },
    );
    addTearDown(coordinator.dispose);
    final first = coordinator.nextOpenGeneration();
    recordMediaEvidence(coordinator, first);
    recordMediaEvidence(coordinator, first);
    expect(calls, 1);
    final second = coordinator.nextOpenGeneration();
    recordMediaEvidence(coordinator, second);
    oldOutput.complete(true);
    await Future<void>.delayed(Duration.zero);

    expect(calls, 2);
    expect(coordinator.firstFrameEvidenceReady, isFalse);
    expect(
      await coordinator.recordVideoOutputLog(
        generation: first,
        prefix: 'vo/gpu',
        level: 'error',
        text: 'Failed initializing any suitable GPU context!',
      ),
      isFalse,
    );
    expect(coordinator.videoOutputFailed, isFalse);
  });

  test('each new open checks output even when the native output is reused',
      () async {
    var calls = 0;
    final coordinator = PlayerPlaybackLifecycleCoordinator(
      readVideoOutputConfigured: () async {
        calls++;
        return true;
      },
    );
    addTearDown(coordinator.dispose);
    for (var open = 0; open < 2; open++) {
      final generation = coordinator.nextOpenGeneration();
      expect(coordinator.firstFrameEvidenceReady, isFalse);
      recordMediaEvidence(coordinator, generation);
      await coordinator.waitForFirstFrameEvidence(generation);
      expect(coordinator.firstFrameEvidenceReady, isTrue);
    }
    expect(calls, 2);
  });

  test('a manual reopen can succeed after the previous renderer failure',
      () async {
    var configured = false;
    final coordinator = PlayerPlaybackLifecycleCoordinator(
      readVideoOutputConfigured: () async => configured,
    );
    addTearDown(coordinator.dispose);
    final first = coordinator.nextOpenGeneration();
    await coordinator.recordVideoOutputLog(
      generation: first,
      prefix: 'vo/gpu',
      level: 'error',
      text: 'Failed initializing any suitable GPU context!',
    );
    expect(coordinator.firstFrameEvidenceReady, isFalse);

    final second = coordinator.nextOpenGeneration();
    expect(coordinator.videoOutputFailed, isFalse);
    configured = true;
    recordMediaEvidence(coordinator, second);
    await coordinator.waitForFirstFrameEvidence(second);
    expect(coordinator.firstFrameEvidenceReady, isTrue);
  });

  test('a late renderer log cannot fail a currently configured output',
      () async {
    final coordinator = PlayerPlaybackLifecycleCoordinator(
      readVideoOutputConfigured: () async => true,
    );
    addTearDown(coordinator.dispose);
    final generation = coordinator.nextOpenGeneration();
    expect(
      await coordinator.recordVideoOutputLog(
        generation: generation,
        prefix: 'cplayer',
        level: 'fatal',
        text:
            'Error opening/initializing the selected video_out (--vo) device.',
      ),
      isFalse,
    );
    expect(coordinator.videoOutputFailed, isFalse);
  });

  test('a failure confirmation cannot terminate a newer open', () async {
    final output = Completer<bool>();
    final coordinator = PlayerPlaybackLifecycleCoordinator(
      readVideoOutputConfigured: () => output.future,
    );
    addTearDown(coordinator.dispose);
    final first = coordinator.nextOpenGeneration();
    final failure = coordinator.recordVideoOutputLog(
      generation: first,
      prefix: 'cplayer',
      level: 'fatal',
      text: 'Error opening/initializing the selected video_out (--vo) device.',
    );
    coordinator.nextOpenGeneration();
    output.complete(false);
    expect(await failure, isFalse);
    expect(coordinator.videoOutputFailed, isFalse);
  });

  test('dispose rejects a late output response and releases its waiter',
      () async {
    final output = Completer<bool>();
    final coordinator = PlayerPlaybackLifecycleCoordinator(
      readVideoOutputConfigured: () => output.future,
    );
    final generation = coordinator.nextOpenGeneration();
    recordMediaEvidence(coordinator, generation);
    final wait = coordinator.waitForFirstFrameEvidence(generation);
    coordinator.dispose();
    output.complete(true);
    await wait;
    await Future<void>.delayed(Duration.zero);
    expect(coordinator.firstFrameEvidenceReady, isFalse);
  });

  test('unavailable native output property never becomes positive evidence',
      () async {
    final coordinator = PlayerPlaybackLifecycleCoordinator(
      readVideoOutputConfigured: () async => throw StateError('disposed'),
    );
    addTearDown(coordinator.dispose);
    final generation = coordinator.nextOpenGeneration();
    recordMediaEvidence(coordinator, generation);
    await Future<void>.delayed(Duration.zero);
    expect(coordinator.firstFrameEvidenceReady, isFalse);
    expect(coordinator.videoOutputFailed, isFalse);
  });

  test('desktop evidence and renderer error handling remain unchanged',
      () async {
    final coordinator = PlayerPlaybackLifecycleCoordinator();
    addTearDown(coordinator.dispose);
    final generation = coordinator.nextOpenGeneration();
    recordMediaEvidence(coordinator, generation);
    expect(coordinator.firstFrameEvidenceReady, isTrue);
    expect(
      await coordinator.recordVideoOutputLog(
        generation: generation,
        prefix: 'vo/gpu',
        level: 'error',
        text: 'Failed initializing any suitable GPU context!',
      ),
      isFalse,
    );
    expect(coordinator.firstFrameEvidenceReady, isTrue);
  });
  test('new open generation cancels watchdogs from the previous open',
      () async {
    var timedOut = false;
    final coordinator = PlayerPlaybackLifecycleCoordinator(
      openTimeout: const Duration(milliseconds: 10),
    );
    final first = coordinator.nextOpenGeneration();
    coordinator.watchOpen(
      generation: first,
      hasProgressOrVideo: () => false,
      onTimeout: () => timedOut = true,
    );

    coordinator.nextOpenGeneration();
    await Future<void>.delayed(const Duration(milliseconds: 25));

    expect(timedOut, isFalse);
    coordinator.dispose();
  });

  test('open watchdog fires only for current stalled generation', () async {
    var timedOut = false;
    final coordinator = PlayerPlaybackLifecycleCoordinator(
      openTimeout: const Duration(milliseconds: 10),
    );
    final generation = coordinator.nextOpenGeneration();
    coordinator.watchOpen(
      generation: generation,
      hasProgressOrVideo: () => false,
      onTimeout: () => timedOut = true,
    );

    await Future<void>.delayed(const Duration(milliseconds: 25));

    expect(timedOut, isTrue);
    coordinator.dispose();
  });

  test('buffering watchdog ignores a stream that advanced', () async {
    var current = Duration.zero;
    var timedOut = false;
    final coordinator = PlayerPlaybackLifecycleCoordinator(
      bufferingTimeout: const Duration(milliseconds: 10),
    );
    final generation = coordinator.nextOpenGeneration();
    coordinator.watchBuffering(
      generation: generation,
      startedAt: current,
      currentPosition: () => current,
      isBuffering: () => true,
      onTimeout: () => timedOut = true,
    );
    current = const Duration(seconds: 2);

    await Future<void>.delayed(const Duration(milliseconds: 25));

    expect(timedOut, isFalse);
    coordinator.dispose();
  });

  test('reconnect is generation isolated', () async {
    var reconnects = 0;
    final coordinator = PlayerPlaybackLifecycleCoordinator(
      reconnectDelay: const Duration(milliseconds: 10),
    );
    final first = coordinator.nextOpenGeneration();
    coordinator.scheduleReconnect(
      generation: first,
      action: () => reconnects++,
    );
    final second = coordinator.nextOpenGeneration();
    coordinator.scheduleReconnect(
      generation: second,
      action: () => reconnects++,
    );

    await Future<void>.delayed(const Duration(milliseconds: 25));

    expect(reconnects, 1);
    coordinator.dispose();
  });

  test('first-frame evidence requires current video metadata and progress',
      () async {
    final coordinator = PlayerPlaybackLifecycleCoordinator();
    final generation = coordinator.nextOpenGeneration();

    coordinator.recordVideoMetadata(
      generation: generation,
      width: 1920,
      height: 1080,
    );
    expect(coordinator.firstFrameEvidenceReady, isFalse);

    coordinator.recordPlaybackPosition(
      generation: generation,
      position: Duration.zero,
    );
    expect(coordinator.firstFrameEvidenceReady, isFalse);

    coordinator.recordPlaybackPosition(
      generation: generation,
      position: const Duration(milliseconds: 1),
    );

    expect(coordinator.firstFrameEvidenceReady, isTrue);
    await coordinator.waitForFirstFrameEvidence(generation);
    coordinator.dispose();
  });

  test('stale media evidence cannot complete the current open', () {
    final coordinator = PlayerPlaybackLifecycleCoordinator();
    final first = coordinator.nextOpenGeneration();
    coordinator.recordVideoMetadata(
      generation: first,
      width: 1920,
      height: 1080,
    );
    final second = coordinator.nextOpenGeneration();

    coordinator.recordPlaybackPosition(
      generation: first,
      position: const Duration(seconds: 2),
    );
    expect(coordinator.firstFrameEvidenceReady, isFalse);

    coordinator.recordPlaybackPosition(
      generation: second,
      position: const Duration(seconds: 2),
    );
    expect(coordinator.firstFrameEvidenceReady, isFalse);

    coordinator.recordVideoMetadata(
      generation: second,
      width: 1280,
      height: 720,
    );
    expect(coordinator.firstFrameEvidenceReady, isTrue);
    coordinator.dispose();
  });
}
