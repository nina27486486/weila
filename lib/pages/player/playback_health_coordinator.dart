import '../../models/playback/playback_source.dart';
import '../../services/playback/playback_auto_selector.dart';
import '../../services/playback/playback_diagnostics.dart';
import '../../services/playback/playback_probe_service.dart';
import '../../services/playback/playback_route_health.dart';
import '../../services/playback/playback_route_health_repository.dart';

class PlaybackHealthCoordinator {
  PlaybackHealthCoordinator({
    required PlaybackProbeService probes,
    required PlaybackRouteHealthRepository repository,
    PlaybackAutoSelector selector = const PlaybackAutoSelector(),
    DateTime Function()? now,
  })  : _probes = probes,
        _repository = repository,
        _selector = selector,
        _now = now ?? DateTime.now;

  final PlaybackProbeService _probes;
  final PlaybackRouteHealthRepository _repository;
  final PlaybackAutoSelector _selector;
  final DateTime Function() _now;
  final Map<String, PlaybackProbeResult> _lastProbes = {};
  Map<String, PlaybackRouteHealth> _health = {};

  Map<String, PlaybackRouteHealth> get health =>
      Map<String, PlaybackRouteHealth>.unmodifiable(_health);

  Future<List<PlaybackSource>> prepareAutoSources({
    required String providerId,
    required List<PlaybackSource> sources,
  }) async {
    if (sources.isEmpty) return const [];
    try {
      _health = await _repository.readAll();
    } catch (_) {
      return List<PlaybackSource>.unmodifiable(sources);
    }

    await Future.wait(
      sources.map((source) async {
        final key = _routeKey(providerId, source);
        _lastProbes[key.storageKey] = await _probes.probe(source);
      }),
    );
    final candidates = <PlaybackAutoCandidate>[];
    for (var index = 0; index < sources.length; index++) {
      final source = sources[index];
      final key = _routeKey(providerId, source);
      candidates.add(
        PlaybackAutoCandidate(
          source: source,
          originalIndex: index,
          key: key,
          health: _health[key.storageKey],
          probe: _lastProbes[key.storageKey],
        ),
      );
    }
    return _selector.order(candidates, now: _now());
  }

  PlaybackDiagnosticsSession beginOpen(int generation) {
    return PlaybackDiagnosticsSession(
      openGeneration: generation,
      now: _now,
    );
  }

  Future<void> finishOpen({
    required String providerId,
    required PlaybackSource source,
    required PlaybackDiagnosticsSnapshot diagnostics,
    required Duration playedDuration,
  }) async {
    final key = _routeKey(providerId, source);
    PlaybackRouteHealth? current = _health[key.storageKey];
    if (current == null) {
      try {
        current = (await _repository.readAll())[key.storageKey];
      } catch (_) {
        current = null;
      }
    }
    current ??= PlaybackRouteHealth(
      samples: 0,
      successRate: 0,
      firstFrameMs: 12000,
      rebufferRatio: 1,
      probeSuccessRate: 0,
      updatedAt: _now(),
    );
    final updated = current.record(
      diagnostics: diagnostics,
      probe: _lastProbes[key.storageKey],
      playedDuration: playedDuration,
      now: _now(),
    );
    _health = Map<String, PlaybackRouteHealth>.from(_health)
      ..[key.storageKey] = updated;
    try {
      await _repository.put(key, updated);
    } catch (_) {
      // Playback health persistence must never block or fail media playback.
    }
  }

  PlaybackRouteKey _routeKey(String providerId, PlaybackSource source) {
    final url = source.variants.isEmpty ? '' : source.variants.first.url;
    final host = Uri.tryParse(url)?.host ?? '';
    return PlaybackRouteKey(
      providerId: providerId,
      sourceKind: source.kind.name,
      sourceId: source.id,
      host: host,
    );
  }
}
