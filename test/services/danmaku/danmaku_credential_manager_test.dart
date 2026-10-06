import 'package:flutter_test/flutter_test.dart';
import 'package:weila/services/danmaku/dandanplay_credentials.dart';
import 'package:weila/services/danmaku/dandanplay_credential_manager.dart';
import 'package:weila/services/danmaku/dandanplay_credential_migrator.dart';
import 'package:weila/services/danmaku/danmaku_credential_store.dart';

void main() {
  test('platform manager accepts an explicitly supplied store', () {
    final store = _MemoryCredentialStore();
    final manager = DanmakuCredentialManager.platform(store: store);
    expect(manager, isA<DanmakuCredentialManager>());
  });

  test('initialize migrates legacy credentials and configures service',
      () async {
    final legacy = <String, Object?>{
      DandanplayCredentialMigrator.legacyAppIdKey: 'legacy-id',
      DandanplayCredentialMigrator.legacyAppSecretKey: 'legacy-secret',
    };
    DandanplayCredentials? applied;
    final manager = DanmakuCredentialManager.testing(
      store: _MemoryCredentialStore(),
      readLegacy: (key) => legacy[key],
      removeLegacy: (key) async => legacy.remove(key),
      applyCredentials: (value) => applied = value,
      clearCredentials: () => applied = null,
    );

    final result = await manager.initialize();

    expect(result.status, CredentialMigrationStatus.migrated);
    expect(manager.credentials?.appId, 'legacy-id');
    expect(applied?.appSecret, 'legacy-secret');
    expect(legacy, isEmpty);
  });

  test('failed migration never configures service from legacy plaintext',
      () async {
    final legacy = <String, Object?>{
      DandanplayCredentialMigrator.legacyAppIdKey: 'legacy-id',
    };
    var applyCount = 0;
    var clearCount = 0;
    final manager = DanmakuCredentialManager.testing(
      store: _MemoryCredentialStore(),
      readLegacy: (key) => legacy[key],
      removeLegacy: (key) async => legacy.remove(key),
      applyCredentials: (_) => applyCount++,
      clearCredentials: () => clearCount++,
    );

    final result = await manager.initialize();

    expect(result.status, CredentialMigrationStatus.failed);
    expect(manager.credentials, isNull);
    expect(applyCount, 0);
    expect(clearCount, 1);
  });

  test('secure store read failure becomes a recoverable migration state',
      () async {
    final legacy = <String, Object?>{
      DandanplayCredentialMigrator.legacyAppIdKey: 'legacy-id',
      DandanplayCredentialMigrator.legacyAppSecretKey: 'legacy-secret',
    };
    var clearCount = 0;
    final manager = DanmakuCredentialManager.testing(
      store: _MemoryCredentialStore(
        readError: StateError('credential manager unavailable'),
      ),
      readLegacy: (key) => legacy[key],
      removeLegacy: (key) async => legacy.remove(key),
      applyCredentials: (_) => fail('明文凭据不得配置到服务'),
      clearCredentials: () => clearCount++,
    );

    final result = await manager.initialize();

    expect(result.status, CredentialMigrationStatus.failed);
    expect(result.safeMessage, isNot(contains('credential manager')));
    expect(manager.migrationFailed, isTrue);
    expect(manager.credentials, isNull);
    expect(clearCount, 1);
    expect(legacy, hasLength(2));
  });

  test('save verifies secure read-back before configuring service', () async {
    DandanplayCredentials? applied;
    final store = _MemoryCredentialStore();
    final manager = DanmakuCredentialManager.testing(
      store: store,
      readLegacy: (_) => null,
      removeLegacy: (_) async {},
      applyCredentials: (value) => applied = value,
      clearCredentials: () => applied = null,
    );

    await manager.save(
      const DandanplayCredentials(
        appId: 'new-id',
        appSecret: 'new-secret',
      ),
    );

    expect(manager.credentials?.appId, 'new-id');
    expect(applied?.appSecret, 'new-secret');
  });

  test('clear deletes secure credentials and clears service', () async {
    var serviceCleared = false;
    final store = _MemoryCredentialStore(
      initial: const DandanplayCredentials(
        appId: 'saved-id',
        appSecret: 'saved-secret',
      ),
    );
    final manager = DanmakuCredentialManager.testing(
      store: store,
      readLegacy: (_) => null,
      removeLegacy: (_) async {},
      applyCredentials: (_) {},
      clearCredentials: () => serviceCleared = true,
    );

    await manager.initialize();
    await manager.clear();

    expect(await store.read(), isNull);
    expect(manager.credentials, isNull);
    expect(serviceCleared, isTrue);
  });
}

class _MemoryCredentialStore implements DanmakuCredentialStore {
  _MemoryCredentialStore({
    DandanplayCredentials? initial,
    this.readError,
  }) : _value = initial;

  DandanplayCredentials? _value;
  final Object? readError;

  @override
  Future<void> clear() async => _value = null;

  @override
  Future<DandanplayCredentials?> read() async {
    if (readError case final error?) throw error;
    return _value;
  }

  @override
  Future<void> write(DandanplayCredentials credentials) async {
    _value = credentials;
  }
}
