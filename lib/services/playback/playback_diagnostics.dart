enum PlaybackFailureKind {
  timeout,
  forbidden,
  notFound,
  server,
  decode,
  noVideo,
  network,
  unknown,
}

enum PlaybackDiagnosticStage {
  idle,
  resolvingSource,
  resolvingManifest,
  opening,
  waitingForFirstFrame,
  playing,
  failed,
  ended,
}

enum PlaybackVideoSignal {
  metadata,
  renderedFrame,
}

typedef PlaybackClock = DateTime Function();

class PlaybackDiagnosticsSnapshot {
  const PlaybackDiagnosticsSnapshot({
    required this.openGeneration,
    required this.firstFrameRendered,
    required this.rebufferCount,
    required this.totalRebufferDuration,
    required this.longestRebufferDuration,
    this.stage = PlaybackDiagnosticStage.idle,
    this.sourceResolveDuration,
    this.manifestDuration,
    this.openDuration,
    this.firstFrameDuration,
    this.failureKind,
  });

  final int openGeneration;
  final bool firstFrameRendered;
  final int rebufferCount;
  final Duration totalRebufferDuration;
  final Duration longestRebufferDuration;
  final PlaybackDiagnosticStage stage;
  final Duration? sourceResolveDuration;
  final Duration? manifestDuration;
  final Duration? openDuration;
  final Duration? firstFrameDuration;
  final PlaybackFailureKind? failureKind;
}

class PlaybackDiagnosticsSession {
  PlaybackDiagnosticsSession({
    required this.openGeneration,
    PlaybackClock? now,
  }) : _now = now ?? DateTime.now;

  static const _minimumRebufferDuration = Duration(milliseconds: 300);

  final int openGeneration;
  final PlaybackClock _now;

  DateTime? _sourceResolveStartedAt;
  Duration? _sourceResolveDuration;
  DateTime? _manifestStartedAt;
  Duration? _manifestDuration;
  DateTime? _openRequestedAt;
  Duration? _openDuration;
  Duration? _firstFrameDuration;
  DateTime? _rebufferStartedAt;
  bool _firstFrameRendered = false;
  bool _ended = false;
  int _rebufferCount = 0;
  Duration _totalRebufferDuration = Duration.zero;
  Duration _longestRebufferDuration = Duration.zero;
  PlaybackFailureKind? _failureKind;
  PlaybackDiagnosticStage _stage = PlaybackDiagnosticStage.idle;

  void sourceResolveStarted() {
    if (_ended || _sourceResolveStartedAt != null) return;
    _sourceResolveStartedAt = _now();
    _stage = PlaybackDiagnosticStage.resolvingSource;
  }

  void sourceResolved() {
    final startedAt = _sourceResolveStartedAt;
    if (_ended || startedAt == null || _sourceResolveDuration != null) return;
    _sourceResolveDuration = _now().difference(startedAt);
    if (_stage == PlaybackDiagnosticStage.resolvingSource) {
      _stage = PlaybackDiagnosticStage.idle;
    }
  }

  void manifestStarted() {
    if (_ended || _manifestStartedAt != null) return;
    _manifestStartedAt = _now();
    _stage = PlaybackDiagnosticStage.resolvingManifest;
  }

  void manifestResolved() {
    final startedAt = _manifestStartedAt;
    if (_ended || startedAt == null || _manifestDuration != null) return;
    _manifestDuration = _now().difference(startedAt);
    if (_stage == PlaybackDiagnosticStage.resolvingManifest) {
      _stage = PlaybackDiagnosticStage.idle;
    }
  }

  void openRequested() {
    if (_ended || _openRequestedAt != null) return;
    _openRequestedAt = _now();
    _stage = PlaybackDiagnosticStage.opening;
  }

  void openCompleted() {
    final requestedAt = _openRequestedAt;
    if (_ended || requestedAt == null || _openDuration != null) return;
    _openDuration = _now().difference(requestedAt);
    _stage = PlaybackDiagnosticStage.waitingForFirstFrame;
  }

  void firstFrameRendered() {
    videoSignalDetected(PlaybackVideoSignal.renderedFrame);
  }

  void videoSignalDetected(PlaybackVideoSignal signal) {
    if (signal != PlaybackVideoSignal.renderedFrame) return;
    final requestedAt = _openRequestedAt;
    if (_ended || _firstFrameRendered) return;
    final renderedAt = _now();
    _firstFrameRendered = true;
    _stage = PlaybackDiagnosticStage.playing;
    if (requestedAt != null) {
      _firstFrameDuration = renderedAt.difference(requestedAt);
    }
  }

  void bufferingChanged(bool buffering) {
    if (_ended || !_firstFrameRendered) return;
    if (buffering) {
      _rebufferStartedAt ??= _now();
      return;
    }
    _finishRebuffer(_now());
  }

  void fail(PlaybackFailureKind kind) {
    if (_ended) return;
    _failureKind ??= kind;
    _stage = PlaybackDiagnosticStage.failed;
  }

  void suspendBuffering() {
    _rebufferStartedAt = null;
  }

  PlaybackDiagnosticsSnapshot end() {
    if (!_ended) {
      _finishRebuffer(_now());
      _ended = true;
      if (_failureKind == null) {
        _stage = PlaybackDiagnosticStage.ended;
      }
    }
    return snapshot;
  }

  PlaybackDiagnosticsSnapshot get snapshot => PlaybackDiagnosticsSnapshot(
        openGeneration: openGeneration,
        firstFrameRendered: _firstFrameRendered,
        rebufferCount: _rebufferCount,
        totalRebufferDuration: _totalRebufferDuration,
        longestRebufferDuration: _longestRebufferDuration,
        stage: _stage,
        sourceResolveDuration: _sourceResolveDuration,
        manifestDuration: _manifestDuration,
        openDuration: _openDuration,
        firstFrameDuration: _firstFrameDuration,
        failureKind: _failureKind,
      );

  void _finishRebuffer(DateTime endedAt) {
    final startedAt = _rebufferStartedAt;
    if (startedAt == null) return;
    _rebufferStartedAt = null;
    final duration = endedAt.difference(startedAt);
    if (duration < _minimumRebufferDuration) return;
    _rebufferCount += 1;
    _totalRebufferDuration += duration;
    if (duration > _longestRebufferDuration) {
      _longestRebufferDuration = duration;
    }
  }
}
