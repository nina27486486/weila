import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:weila/models/playback/playback_source.dart';
import 'package:weila/pages/player/playback_health_coordinator.dart';
import 'package:weila/services/playback/playback_probe_service.dart';
import 'package:weila/services/playback/playback_route_health.dart';
import 'package:weila/services/playback/playback_route_health_repository.dart';

PlaybackSource _source(String id) {
  return PlaybackSource(
    id: id,
    label: id,
    kind: PlaybackSourceKind.cms,
    headers: const {'Referer': 'https://site.example/'},
    variants: [
      PlaybackVariant(
        id: '$id-original',
        label: '原始',
        url: 'https://$id.example/master.m3u8?token=private',
        kind: PlaybackVariantKind.original,
      ),
    ],
  );
}

PlaybackRouteHealth _health({
  required DateTime now,
  required double successRate,
  required double firstFrameMs,
}) {
  return PlaybackRouteHealth(
    samples: 4,
    successRate: successRate,
    firstFrameMs: firstFrameMs,
    rebufferRatio: successRate > .9 ? 0 : .2,
    probeSuccessRate: successRate,
    updatedAt: now,
  );
}

void main() {
  test('probes every candidate before automatic ordering', () async {
    final now = DateTime.utc(2026, 7, 11, 12);
    final probedHosts = <String>[];
    final probes = PlaybackProbeService(
      now: () => now,
      load: (
          {required uri,
          required headers,
          required manifest,
          required maxBytes}) async {
        probedHosts.add(uri.host);
        return PlaybackProbePayload(
          statusCode: 200,
          elapsed: const Duration(milliseconds: 50),
          bytesRead: 8,
          prefix: utf8.encode('#EXTM3U\n'),
        );
      },
    );
    final repository = _MemoryHealthRepository({
      'provider|cms|main|main.example': _health(
        now: now,
        successRate: .7,
        firstFrameMs: 8000,
      ),
      'provider|cms|backup|backup.example': _health(
        now: now,
        successRate: .98,
        firstFrameMs: 1200,
      ),
    });
    final coordinator = PlaybackHealthCoordinator(
      probes: probes,
      repository: repository,
      now: () => now,
    );

    final ordered = await coordinator.prepareAutoSources(
      providerId: 'provider',
      sources: [_source('main'), _source('backup'), _source('third')],
    );

    expect(probedHosts, ['main.example', 'backup.example', 'third.example']);
    expect(ordered.map((source) => source.id), ['backup', 'main', 'third']);
  });

  test('repository read failure preserves original source order', () async {
    final now = DateTime.utc(2026, 7, 11, 12);
    final coordinator = PlaybackHealthCoordinator(
      probes: PlaybackProbeService(
        load: (
            {required uri,
            required headers,
            required manifest,
            required maxBytes}) async {
          return PlaybackProbePayload(
            statusCode: 200,
            elapsed: const Duration(milliseconds: 20),
            bytesRead: 8,
            prefix: utf8.encode('#EXTM3U\n'),
          );
        },
      ),
      repository: _ThrowingHealthRepository(),
      now: () => now,
    );

    final ordered = await coordinator.prepareAutoSources(
      providerId: 'provider',
      sources: [_source('main'), _source('backup')],
    );

    expect(ordered.map((source) => source.id), ['main', 'backup']);
  });

  test('settles a diagnostics snapshot under a secret-free route key',
      () async {
    final now = DateTime.utc(2026, 7, 11, 12);
    final repository = _MemoryHealthRepository();
    final coordinator = PlaybackHealthCoordinator(
      probes: PlaybackProbeService(
        load: (
            {required uri,
            required headers,
            required manifest,
            required maxBytes}) async {
          throw StateError('unused');
        },
      ),
      repository: repository,
      now: () => now,
    );
    final session = coordinator.beginOpen(12)
      ..openRequested()
      ..firstFrameRendered();

    await coordinator.finishOpen(
      providerId: 'provider',
      source: _source('main'),
      diagnostics: session.end(),
      playedDuration: const Duration(minutes: 2),
    );

    expect(repository.lastPutKey, isNotNull);
    expect(repository.lastPutKey!.storageKey, 'provider|cms|main|main.example');
    expect(repository.lastPutKey!.storageKey, isNot(contains('http')));
    expect(repository.lastPutKey!.storageKey, isNot(contains('token')));
    expect(repository.values.values.single.samples, 1);
    expect(repository.values.values.single.successRate, 1);
  });
}

class _MemoryHealthRepository implements PlaybackRouteHealthRepository {
  _MemoryHealthRepository([Map<String, PlaybackRouteHealth>? initial])
      : values = Map<String, PlaybackRouteHealth>.from(initial ?? const {});

  final Map<String, PlaybackRouteHealth> values;
  PlaybackRouteKey? lastPutKey;

  @override
  Future<void> clear() async => values.clear();

  @override
  Future<void> put(PlaybackRouteKey key, PlaybackRouteHealth health) async {
    lastPutKey = key;
    values[key.storageKey] = health;
  }

  @override
  Future<Map<String, PlaybackRouteHealth>> readAll() async =>
      Map<String, PlaybackRouteHealth>.from(values);
}

class _ThrowingHealthRepository implements PlaybackRouteHealthRepository {
  @override
  Future<void> clear() async {}

  @override
  Future<void> put(PlaybackRouteKey key, PlaybackRouteHealth health) async {}

  @override
  Future<Map<String, PlaybackRouteHealth>> readAll() {
    throw StateError('storage unavailable');
  }
}
