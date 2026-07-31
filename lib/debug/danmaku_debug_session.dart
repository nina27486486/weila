import 'package:flutter/foundation.dart';

import '../services/danmaku/danmaku_diagnostics.dart';
import '../services/danmaku/danmaku_load_result.dart';
import '../services/danmaku/danmaku_matcher.dart';
import '../services/danmaku/danmaku_service.dart';
import '../widgets/danmaku_overlay.dart';
import 'fake_player.dart';

abstract interface class DanmakuDebugSource {
  Future<DanmakuLoadResult> load({
    required String anime,
    required int episode,
    bool refresh = false,
  });

  Future<DanmakuLoadResult> choose({
    required String anime,
    required int episode,
    required DanmakuMatchCandidate candidate,
  });
}

class DanmakuServiceDebugSource implements DanmakuDebugSource {
  DanmakuServiceDebugSource(this.service);

  final DanmakuService service;

  @override
  Future<DanmakuLoadResult> load({
    required String anime,
    required int episode,
    bool refresh = false,
  }) {
    return service.load(anime: anime, episode: episode, refresh: refresh);
  }

  @override
  Future<DanmakuLoadResult> choose({
    required String anime,
    required int episode,
    required DanmakuMatchCandidate candidate,
  }) {
    return service.choose(
      anime: anime,
      episode: episode,
      candidate: candidate,
    );
  }
}

class DanmakuDebugSession extends ChangeNotifier {
  DanmakuDebugSession({
    required DanmakuDebugSource source,
    required this.player,
    required this.controller,
  }) : _source = source {
    player.addListener(_syncTimeline);
    controller.addListener(_handleControllerChange);
  }

  final DanmakuDebugSource _source;
  final FakePlayer player;
  final DanmakuController controller;

  DanmakuLoadDiagnostics _loadDiagnostics = DanmakuLoadDiagnostics.empty;
  DanmakuErrorStage _runtimeErrorStage = DanmakuErrorStage.none;
  List<DanmakuMatchCandidate> _candidates = const [];
  DanmakuLoadStatus? _loadStatus;
  String? _safeMessage;
  String _anime = '';
  int _episode = 1;
  bool _loading = false;

  List<DanmakuMatchCandidate> get candidates => _candidates;
  DanmakuLoadStatus? get loadStatus => _loadStatus;
  String? get safeMessage => _safeMessage;
  bool get loading => _loading;

  void seek(Duration target) {
    controller.seekTo(target.inMilliseconds / 1000.0);
    player.seek(target);
  }

  DanmakuDebugSnapshot get snapshot {
    final render = controller.diagnostics;
    var errorStage = _loadDiagnostics.errorStage;
    if (errorStage == DanmakuErrorStage.none &&
        _runtimeErrorStage != DanmakuErrorStage.none) {
      errorStage = _runtimeErrorStage;
    }
    if (errorStage == DanmakuErrorStage.none && render.renderError != null) {
      errorStage = DanmakuErrorStage.render;
    }
    return DanmakuDebugSnapshot(
      episodeId: _loadDiagnostics.episodeId,
      commentCount: _loadDiagnostics.commentCount,
      parsedCount: _loadDiagnostics.parsedCount,
      queuedCount: render.queuedCount,
      currentTime: render.currentTime,
      emittedCount: render.emittedCount,
      renderedCount: render.renderedCount,
      danmakuEnabled: render.danmakuEnabled,
      opacity: render.opacity,
      area: render.area,
      errorStage: errorStage,
    );
  }

  Future<void> load({
    required String anime,
    required int episode,
    bool refresh = false,
  }) async {
    _anime = anime.trim();
    _episode = episode;
    _beginLoad();
    try {
      final result = await _source.load(
        anime: _anime,
        episode: _episode,
        refresh: refresh,
      );
      _applyResult(result);
    } catch (_) {
      _runtimeErrorStage = DanmakuErrorStage.search;
      _safeMessage = '弹幕调试加载失败';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> choose(DanmakuMatchCandidate candidate) async {
    _beginLoad(clearTimeline: false);
    try {
      final result = await _source.choose(
        anime: _anime,
        episode: _episode,
        candidate: candidate,
      );
      _applyResult(result);
    } catch (_) {
      _runtimeErrorStage = DanmakuErrorStage.comments;
      _safeMessage = '候选剧集弹幕加载失败';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void _beginLoad({bool clearTimeline = true}) {
    _loading = true;
    _runtimeErrorStage = DanmakuErrorStage.none;
    _safeMessage = null;
    if (clearTimeline) player.reset();
    controller.loadDanmaku(const []);
    notifyListeners();
  }

  void _applyResult(DanmakuLoadResult result) {
    _loadStatus = result.status;
    _loadDiagnostics = result.diagnostics;
    _safeMessage = result.safeMessage;
    _candidates = List<DanmakuMatchCandidate>.unmodifiable(result.candidates);
    if (result.status != DanmakuLoadStatus.loaded) return;
    try {
      controller.loadDanmaku(result.items);
      _candidates = const [];
    } catch (_) {
      _runtimeErrorStage = DanmakuErrorStage.queue;
      _safeMessage = '弹幕加入渲染队列失败';
    }
  }

  void _syncTimeline() {
    try {
      controller.updatePosition(player.position.inMilliseconds / 1000.0);
    } catch (_) {
      _runtimeErrorStage = DanmakuErrorStage.sync;
      _safeMessage = '本地时间轴同步失败';
    }
    notifyListeners();
  }

  void _handleControllerChange() => notifyListeners();

  @override
  void dispose() {
    player.removeListener(_syncTimeline);
    controller.removeListener(_handleControllerChange);
    player.dispose();
    controller.dispose();
    super.dispose();
  }
}
