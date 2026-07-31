import '../storage/storage_service.dart';
import 'dandanplay_credential_migrator.dart';
import 'dandanplay_credentials.dart';
import 'danmaku_credential_store.dart';
import 'danmaku_service.dart';
import 'windows_danmaku_credential_store.dart';

typedef CredentialsApplier = void Function(DandanplayCredentials credentials);
typedef CredentialsClearer = void Function();

class DanmakuCredentialManager {
  factory DanmakuCredentialManager() => _instance;

  DanmakuCredentialManager.testing({
    required DanmakuCredentialStore store,
    required LegacyCredentialReader readLegacy,
    required LegacyCredentialRemover removeLegacy,
    required CredentialsApplier applyCredentials,
    required CredentialsClearer clearCredentials,
  }) : this._(
          store: store,
          readLegacy: readLegacy,
          removeLegacy: removeLegacy,
          applyCredentials: applyCredentials,
          clearCredentials: clearCredentials,
        );

  DanmakuCredentialManager._({
    required DanmakuCredentialStore store,
    required LegacyCredentialReader readLegacy,
    required LegacyCredentialRemover removeLegacy,
    required CredentialsApplier applyCredentials,
    required CredentialsClearer clearCredentials,
  })  : _store = store,
        _readLegacy = readLegacy,
        _removeLegacy = removeLegacy,
        _applyCredentials = applyCredentials,
        _clearCredentials = clearCredentials;

  static final DanmakuCredentialManager _instance = DanmakuCredentialManager._(
    store: WindowsDanmakuCredentialStore(),
    readLegacy: (key) => StorageService().getSetting<Object>(key),
    removeLegacy: StorageService().removeSetting,
    applyCredentials: (credentials) => DanmakuService().setCredentials(
      credentials.appId,
      credentials.appSecret,
    ),
    clearCredentials: DanmakuService().clearCredentials,
  );

  final DanmakuCredentialStore _store;
  final LegacyCredentialReader _readLegacy;
  final LegacyCredentialRemover _removeLegacy;
  final CredentialsApplier _applyCredentials;
  final CredentialsClearer _clearCredentials;

  DandanplayCredentials? _credentials;
  CredentialMigrationResult? _migrationResult;

  DandanplayCredentials? get credentials => _credentials;

  CredentialMigrationResult? get migrationResult => _migrationResult;

  bool get hasCredentials => _credentials?.isValid ?? false;

  bool get migrationFailed => _migrationResult?.failed ?? false;

  Future<CredentialMigrationResult> initialize() async {
    final migrator = DandanplayCredentialMigrator(
      store: _store,
      readLegacy: _readLegacy,
      removeLegacy: _removeLegacy,
    );
    var result = await migrator.migrateLegacyHiveCredentials();
    _migrationResult = result;
    try {
      await _loadSecureCredentials();
    } catch (_) {
      _credentials = null;
      _clearCredentials();
      result = const CredentialMigrationResult(
        status: CredentialMigrationStatus.failed,
        safeMessage: '安全凭据暂时不可用，旧数据已保留，请在设置中重试。',
      );
      _migrationResult = result;
    }
    return result;
  }

  Future<CredentialMigrationResult> retryMigration() => initialize();

  Future<void> save(DandanplayCredentials credentials) async {
    if (!credentials.isValid) {
      throw ArgumentError('弹弹play AppId 与 AppSecret 均不能为空。');
    }
    await _store.write(credentials);
    final verified = await _store.read();
    if (!_matches(verified, credentials)) {
      throw StateError('安全凭据回读校验失败。');
    }
    await _removeLegacy(DandanplayCredentialMigrator.legacyAppIdKey);
    await _removeLegacy(DandanplayCredentialMigrator.legacyAppSecretKey);
    _credentials = verified;
    _applyCredentials(verified!);
    _migrationResult = const CredentialMigrationResult(
      status: CredentialMigrationStatus.alreadySecure,
      safeMessage: '弹弹play凭据已安全保存。',
    );
  }

  Future<void> clear() async {
    await _store.clear();
    await _removeLegacy(DandanplayCredentialMigrator.legacyAppIdKey);
    await _removeLegacy(DandanplayCredentialMigrator.legacyAppSecretKey);
    _credentials = null;
    _clearCredentials();
  }

  Future<void> _loadSecureCredentials() async {
    final value = await _store.read();
    if (value?.isValid ?? false) {
      _credentials = value;
      _applyCredentials(value!);
      return;
    }
    _credentials = null;
    _clearCredentials();
  }

  static bool _matches(
    DandanplayCredentials? left,
    DandanplayCredentials right,
  ) {
    return left?.appId == right.appId && left?.appSecret == right.appSecret;
  }
}
