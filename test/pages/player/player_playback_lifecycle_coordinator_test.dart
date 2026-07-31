import 'package:flutter_test/flutter_test.dart';
import 'package:weila/pages/player/player_playback_lifecycle_coordinator.dart';

void main() {
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
