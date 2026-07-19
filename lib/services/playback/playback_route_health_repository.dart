import 'playback_route_health.dart';

typedef PlaybackHealthSettingsRead = Object? Function(String key);
typedef PlaybackHealthSettingsWrite = Future<void> Function(
  String key,
  Object value,
);
typedef PlaybackHealthSettingsRemove = Future<void> Function(String key);

abstract interface class PlaybackRouteHealthRepository {
  Future<Map<String, PlaybackRouteHealth>> readAll();
  Future<void> put(PlaybackRouteKey key, PlaybackRouteHealth health);
  Future<void> clear();
}

class SettingsPlaybackRouteHealthRepository
    implements PlaybackRouteHealthRepository {
  SettingsPlaybackRouteHealthRepository({
    required PlaybackHealthSettingsRead read,
    required PlaybackHealthSettingsWrite write,
    required PlaybackHealthSettingsRemove remove,
    DateTime Function()? now,
  })  : _read = read,
        _write = write,
        _remove = remove,
        _now = now ?? DateTime.now;

  static const storageKey = 'playback_route_health_v1';
  static const _maximumEntries = 200;
  static const _retention = Duration(days: 30);

  final PlaybackHealthSettingsRead _read;
  final PlaybackHealthSettingsWrite _write;
  final PlaybackHealthSettingsRemove _remove;
  final DateTime Function() _now;

  @override
  Future<Map<String, PlaybackRouteHealth>> readAll() async {
    final root = _read(storageKey);
    if (root is! Map || root['version'] != 1 || root['entries'] is! Map) {
      return <String, PlaybackRouteHealth>{};
    }
    final now = _now().toUtc();
    final result = <String, PlaybackRouteHealth>{};
    for (final entry in (root['entries'] as Map).entries) {
      if (entry.key is! String) continue;
      final health = PlaybackRouteHealth.tryParse(entry.value);
      if (health == null) continue;
      if (now.difference(health.updatedAt.toUtc()) > _retention) continue;
      result[entry.key as String] = health;
    }
    return result;
  }

  @override
  Future<void> put(
    PlaybackRouteKey key,
    PlaybackRouteHealth health,
  ) async {
    final entries = await readAll();
    entries[key.storageKey] = health;
    final sorted = entries.entries.toList()
      ..sort((a, b) => b.value.updatedAt.compareTo(a.value.updatedAt));
    final limited = <String, dynamic>{};
    for (final entry in sorted.take(_maximumEntries)) {
      limited[entry.key] = entry.value.toMap();
    }
    await _write(storageKey, {
      'version': 1,
      'entries': limited,
    });
  }

  @override
  Future<void> clear() => _remove(storageKey);
}
