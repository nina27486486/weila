import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:weila/services/playback/playback_route_health.dart';
import 'package:weila/services/playback/playback_route_health_repository.dart';

PlaybackRouteHealth _storedHealth(DateTime updatedAt, {int samples = 3}) {
  return PlaybackRouteHealth(
    samples: samples,
    successRate: .9,
    firstFrameMs: 1800,
    rebufferRatio: .01,
    probeSuccessRate: 1,
    updatedAt: updatedAt,
  );
}

void main() {
  test('ignores malformed and entries older than thirty days', () async {
    final now = DateTime.utc(2026, 7, 11, 12);
    Object? stored = {
      'version': 1,
      'entries': {
        'valid|cms|main|media.example':
            _storedHealth(now.subtract(const Duration(days: 2))).toMap(),
        'expired|cms|old|old.example':
            _storedHealth(now.subtract(const Duration(days: 31))).toMap(),
        'malformed|cms|bad|bad.example': {'samples': 'not-a-number'},
      },
    };
    final repository = SettingsPlaybackRouteHealthRepository(
      read: (_) => stored,
      write: (_, value) async => stored = value,
      remove: (_) async => stored = null,
      now: () => now,
    );

    final result = await repository.readAll();

    expect(result.keys, ['valid|cms|main|media.example']);
  });

  test('put keeps only two hundred newest safe entries', () async {
    final now = DateTime.utc(2026, 7, 11, 12);
    final entries = <String, dynamic>{};
    for (var i = 0; i < 205; i++) {
      entries['provider|cms|source-$i|media-$i.example'] = _storedHealth(
        now.subtract(Duration(minutes: 205 - i)),
      ).toMap();
    }
    Object? stored = {'version': 1, 'entries': entries};
    final repository = SettingsPlaybackRouteHealthRepository(
      read: (_) => stored,
      write: (_, value) async => stored = value,
      remove: (_) async => stored = null,
      now: () => now,
    );

    await repository.put(
      const PlaybackRouteKey(
        providerId: 'provider',
        sourceKind: 'cms',
        sourceId: 'newest',
        host: 'fresh.example',
      ),
      _storedHealth(now),
    );

    final result = await repository.readAll();
    final serialized = jsonEncode(stored);
    expect(result, hasLength(200));
    expect(result, contains('provider|cms|newest|fresh.example'));
    expect(serialized, isNot(contains('http')));
    expect(serialized, isNot(contains('?')));
    expect(serialized, isNot(contains('Referer')));
    expect(serialized, isNot(contains('Cookie')));
    expect(serialized, isNot(contains('Authorization')));
  });

  test('corrupt roots return empty and clear removes the setting', () async {
    final now = DateTime.utc(2026, 7, 11, 12);
    Object? stored = 'corrupt';
    var removedKey = '';
    final repository = SettingsPlaybackRouteHealthRepository(
      read: (_) => stored,
      write: (_, value) async => stored = value,
      remove: (key) async {
        removedKey = key;
        stored = null;
      },
      now: () => now,
    );

    expect(await repository.readAll(), isEmpty);
    await repository.clear();
    expect(removedKey, 'playback_route_health_v1');
    expect(stored, isNull);
  });
}
