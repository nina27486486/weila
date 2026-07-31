import 'package:flutter_test/flutter_test.dart';
import 'package:weila/services/danmaku/dandanplay_credentials.dart';
import 'package:weila/services/danmaku/danmaku_credential_store.dart';
import 'package:weila/services/danmaku/dandanplay_credential_migrator.dart';

void main() {
  test('writes and verifies secure credentials before removing legacy values',
      () async {
    final legacy = <String, Object?>{
      DandanplayCredentialMigrator.legacyAppIdKey: 'app-id',
      DandanplayCredentialMigrator.legacyAppSecretKey: 'app-secret',
    };
    final store = _MemoryCredentialStore();
    final migrator = DandanplayCredentialMigrator(
      store: store,
      readLegacy: (key) => legacy[key],
      removeLegacy: (key) async => legacy.remove(key),
    );

    final result = await migrator.migrateLegacyHiveCredentials();

    expect(result.status, CredentialMigrationStatus.migrated);
    expect((await store.read())?.appId, 'app-id');
    expect((await store.read())?.appSecret, 'app-secret');
    expect(legacy, isEmpty);
  });

  test('keeps legacy values when secure read-back does not match', () async {
    final legacy = <String, Object?>{
      DandanplayCredentialMigrator.legacyAppIdKey: 'app-id',
      DandanplayCredentialMigrator.legacyAppSecretKey: 'app-secret',
    };
    final store = _MemoryCredentialStore(readBackOverride: const [
      DandanplayCredentials(appId: 'other', appSecret: 'wrong'),
    ]);
    final migrator = DandanplayCredentialMigrator(
      store: store,
      readLegacy: (key) => legacy[key],
      removeLegacy: (key) async => legacy.remove(key),
    );

    final result = await migrator.migrateLegacyHiveCredentials();

    expect(result.status, CredentialMigrationStatus.failed);
    expect(result.safeMessage, isNot(contains('app-secret')));
    expect(legacy, hasLength(2));
  });

  test('clears stale legacy values when secure credentials already exist',
      () async {
    final legacy = <String, Object?>{
      DandanplayCredentialMigrator.legacyAppIdKey: 'old-id',
      DandanplayCredentialMigrator.legacyAppSecretKey: 'old-secret',
    };
    final store = _MemoryCredentialStore(
      initial: const DandanplayCredentials(
        appId: 'secure-id',
        appSecret: 'secure-secret',
      ),
    );
    final migrator = DandanplayCredentialMigrator(
      store: store,
      readLegacy: (key) => legacy[key],
      removeLegacy: (key) async => legacy.remove(key),
    );

    final result = await migrator.migrateLegacyHiveCredentials();

    expect(result.status, CredentialMigrationStatus.alreadySecure);
    expect(legacy, isEmpty);
    expect((await store.read())?.appId, 'secure-id');
  });

  test('reports incomplete legacy credentials without deleting them', () async {
    final legacy = <String, Object?>{
      DandanplayCredentialMigrator.legacyAppIdKey: 'app-id',
    };
    final migrator = DandanplayCredentialMigrator(
      store: _MemoryCredentialStore(),
      readLegacy: (key) => legacy[key],
      removeLegacy: (key) async => legacy.remove(key),
    );

    final result = await migrator.migrateLegacyHiveCredentials();

    expect(result.status, CredentialMigrationStatus.failed);
    expect(legacy, hasLength(1));
  });
}

class _MemoryCredentialStore implements DanmakuCredentialStore {
  _MemoryCredentialStore({
    DandanplayCredentials? initial,
    List<DandanplayCredentials?>? readBackOverride,
  })  : _value = initial,
        _readBackOverride = readBackOverride ?? [];

  DandanplayCredentials? _value;
  final List<DandanplayCredentials?> _readBackOverride;

  @override
  Future<void> clear() async => _value = null;

  @override
  Future<DandanplayCredentials?> read() async {
    if (_readBackOverride.isNotEmpty) {
      return _readBackOverride.removeAt(0);
    }
    return _value;
  }

  @override
  Future<void> write(DandanplayCredentials credentials) async {
    _value = credentials;
  }
}
