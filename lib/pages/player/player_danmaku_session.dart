import '../../services/danmaku/danmaku_load_result.dart';
import '../../services/danmaku/danmaku_matcher.dart';
import '../../services/danmaku/danmaku_service.dart';
import '../../widgets/danmaku_overlay.dart';

abstract interface class PlayerDanmakuGateway {
  bool get hasCredentials;

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

class DanmakuServiceGateway implements PlayerDanmakuGateway {
  DanmakuServiceGateway(this._service);

  final DanmakuService _service;

  @override
  bool get hasCredentials => _service.hasCredentials;

  @override
  Future<DanmakuLoadResult> load({
    required String anime,
    required int episode,
    bool refresh = false,
  }) {
    return _service.load(
      anime: anime,
      episode: episode,
      refresh: refresh,
    );
  }

  @override
  Future<DanmakuLoadResult> choose({
    required String anime,
    required int episode,
    required DanmakuMatchCandidate candidate,
  }) {
    return _service.choose(
      anime: anime,
      episode: episode,
      candidate: candidate,
    );
  }
}

class PlayerDanmakuSession {
  PlayerDanmakuSession({
    required PlayerDanmakuGateway gateway,
    required this.controller,
    this.onChanged,
  }) : _gateway = gateway;

  final PlayerDanmakuGateway _gateway;
  final DanmakuController controller;
  final void Function(DanmakuLoadResult result)? onChanged;

  DanmakuLoadResult _result = DanmakuLoadResult(
    status: DanmakuLoadStatus.noMatch,
  );
  int _generation = 0;
  bool _disposed = false;

  DanmakuLoadResult get result => _result;

  Future<void> load({
    required String anime,
    required int episode,
    bool refresh = false,
  }) async {
    final generation = ++_generation;
    _publish(
      DanmakuLoadResult(
        status: _gateway.hasCredentials
            ? DanmakuLoadStatus.searching
            : DanmakuLoadStatus.notConfigured,
      ),
      clearItems: true,
    );
    final result = await _gateway.load(
      anime: anime,
      episode: episode,
      refresh: refresh,
    );
    if (_disposed || generation != _generation) return;
    _publish(result, loadItems: true);
  }

  Future<void> choose({
    required String anime,
    required int episode,
    required DanmakuMatchCandidate candidate,
  }) async {
    final generation = ++_generation;
    _publish(
      DanmakuLoadResult(
        status: DanmakuLoadStatus.loading,
        selected: candidate,
      ),
    );
    final result = await _gateway.choose(
      anime: anime,
      episode: episode,
      candidate: candidate,
    );
    if (_disposed || generation != _generation) return;
    _publish(result, loadItems: true);
  }

  void clear() {
    _generation++;
    controller.loadDanmaku(const []);
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _generation++;
    controller.dispose();
  }

  void _publish(
    DanmakuLoadResult value, {
    bool clearItems = false,
    bool loadItems = false,
  }) {
    if (_disposed) return;
    _result = value;
    if (clearItems) controller.loadDanmaku(const []);
    if (loadItems) controller.loadDanmaku(value.items);
    onChanged?.call(value);
  }
}
