import 'dart:async';

class PlayerPlaybackLifecycleCoordinator {
  PlayerPlaybackLifecycleCoordinator({
    this.openTimeout = const Duration(seconds: 20),
    this.noVideoTimeout = const Duration(seconds: 12),
    this.bufferingTimeout = const Duration(seconds: 25),
    this.reconnectDelay = const Duration(milliseconds: 900),
  });

  final Duration openTimeout;
  final Duration noVideoTimeout;
  final Duration bufferingTimeout;
  final Duration reconnectDelay;

  int _generation = 0;
  Timer? _openTimer;
  Timer? _noVideoTimer;
  Timer? _bufferingTimer;
  Timer? _reconnectTimer;
  Completer<void> _firstFrameEvidence = Completer<void>();
  int _firstFrameGeneration = 0;
  bool _videoMetadataDetected = false;
  bool _playbackPositionAdvanced = false;
  bool _disposed = false;

  int get currentGeneration => _generation;

  bool get reconnectScheduled => _reconnectTimer?.isActive ?? false;

  bool get firstFrameEvidenceReady =>
      _firstFrameGeneration == _generation &&
      _firstFrameEvidence.isCompleted;

  int nextOpenGeneration() {
    _ensureActive();
    if (!_firstFrameEvidence.isCompleted) {
      _firstFrameEvidence.complete();
    }
    _generation++;
    _firstFrameGeneration = _generation;
    _firstFrameEvidence = Completer<void>();
    _videoMetadataDetected = false;
    _playbackPositionAdvanced = false;
    cancelWatchdogs();
    return _generation;
  }

  bool isCurrent(int generation) => !_disposed && generation == _generation;

  void recordVideoMetadata({
    required int generation,
    required int width,
    required int height,
  }) {
    if (!isCurrent(generation) || width <= 0 || height <= 0) return;
    _videoMetadataDetected = true;
    _completeFirstFrameEvidence();
  }

  void recordPlaybackPosition({
    required int generation,
    required Duration position,
  }) {
    if (!isCurrent(generation) || position <= Duration.zero) return;
    _playbackPositionAdvanced = true;
    _completeFirstFrameEvidence();
  }

  Future<void> waitForFirstFrameEvidence(int generation) {
    if (!isCurrent(generation) || generation != _firstFrameGeneration) {
      return Future<void>.value();
    }
    return _firstFrameEvidence.future;
  }

  void watchOpen({
    required int generation,
    required bool Function() hasProgressOrVideo,
    required void Function() onTimeout,
  }) {
    _openTimer?.cancel();
    _openTimer = Timer(openTimeout, () {
      if (!isCurrent(generation) || hasProgressOrVideo()) return;
      onTimeout();
    });
  }

  void watchNoVideo({
    required int generation,
    required bool Function() shouldReport,
    required void Function() onTimeout,
  }) {
    _noVideoTimer?.cancel();
    _noVideoTimer = Timer(noVideoTimeout, () {
      if (!isCurrent(generation) || !shouldReport()) return;
      onTimeout();
    });
  }

  void watchBuffering({
    required int generation,
    required Duration startedAt,
    required Duration Function() currentPosition,
    required bool Function() isBuffering,
    required void Function() onTimeout,
  }) {
    _bufferingTimer?.cancel();
    _bufferingTimer = Timer(bufferingTimeout, () {
      if (!isCurrent(generation) || !isBuffering()) return;
      if (currentPosition() - startedAt > const Duration(seconds: 1)) return;
      onTimeout();
    });
  }

  void cancelBufferingWatchdog() {
    _bufferingTimer?.cancel();
    _bufferingTimer = null;
  }

  void markVideoSignalDetected() {
    _openTimer?.cancel();
    _openTimer = null;
    _noVideoTimer?.cancel();
    _noVideoTimer = null;
  }

  void scheduleReconnect({
    required int generation,
    required void Function() action,
  }) {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(reconnectDelay, () {
      if (!isCurrent(generation)) return;
      action();
    });
  }

  void cancelWatchdogs() {
    _openTimer?.cancel();
    _noVideoTimer?.cancel();
    _bufferingTimer?.cancel();
    _reconnectTimer?.cancel();
    _openTimer = null;
    _noVideoTimer = null;
    _bufferingTimer = null;
    _reconnectTimer = null;
  }

  void dispose() {
    if (_disposed) return;
    cancelWatchdogs();
    if (!_firstFrameEvidence.isCompleted) {
      _firstFrameEvidence.complete();
    }
    _disposed = true;
    _generation++;
  }

  void _completeFirstFrameEvidence() {
    if (!_videoMetadataDetected ||
        !_playbackPositionAdvanced ||
        _firstFrameEvidence.isCompleted) {
      return;
    }
    _firstFrameEvidence.complete();
  }

  void _ensureActive() {
    if (_disposed) {
      throw StateError('播放生命周期协调器已经释放。');
    }
  }
}
