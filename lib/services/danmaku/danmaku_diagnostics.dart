enum DanmakuErrorStage {
  none,
  credentials,
  search,
  match,
  comments,
  parse,
  queue,
  sync,
  render,
}

class DanmakuLoadDiagnostics {
  const DanmakuLoadDiagnostics({
    this.episodeId,
    this.commentCount = 0,
    this.parsedCount = 0,
    this.errorStage = DanmakuErrorStage.none,
  });

  static const empty = DanmakuLoadDiagnostics();

  final int? episodeId;
  final int commentCount;
  final int parsedCount;
  final DanmakuErrorStage errorStage;
}

class DanmakuControllerDiagnostics {
  const DanmakuControllerDiagnostics({
    required this.queuedCount,
    required this.emittedCount,
    required this.renderedCount,
    required this.currentTime,
    required this.danmakuEnabled,
    required this.opacity,
    required this.area,
    this.renderError,
  });

  final int queuedCount;
  final int emittedCount;
  final int renderedCount;
  final double currentTime;
  final bool danmakuEnabled;
  final double opacity;
  final double area;
  final String? renderError;
}

class DanmakuDebugSnapshot {
  const DanmakuDebugSnapshot({
    required this.episodeId,
    required this.commentCount,
    required this.parsedCount,
    required this.queuedCount,
    required this.currentTime,
    required this.emittedCount,
    required this.renderedCount,
    required this.danmakuEnabled,
    required this.opacity,
    required this.area,
    required this.errorStage,
  });

  final int? episodeId;
  final int commentCount;
  final int parsedCount;
  final int queuedCount;
  final double currentTime;
  final int emittedCount;
  final int renderedCount;
  final bool danmakuEnabled;
  final double opacity;
  final double area;
  final DanmakuErrorStage errorStage;

  String toSafeText() => [
        'episodeId: ${episodeId ?? 'null'}',
        'commentCount: $commentCount',
        'parsedCount: $parsedCount',
        'queuedCount: $queuedCount',
        'currentTime: ${currentTime.toStringAsFixed(1)}',
        'emittedCount: $emittedCount',
        'renderedCount: $renderedCount',
        'danmakuEnabled: $danmakuEnabled',
        'opacity: ${opacity.toStringAsFixed(2)}',
        'area: ${area.toStringAsFixed(2)}',
        'errorStage: ${errorStage.name}',
      ].join('\n');
}
