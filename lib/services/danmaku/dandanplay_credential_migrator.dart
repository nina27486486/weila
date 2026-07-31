import 'danmaku_credential_store.dart';
import 'dandanplay_credentials.dart';

enum CredentialMigrationStatus {
  noLegacyCredentials,
  alreadySecure,
  migrated,
  failed,
}

class CredentialMigrationResult {
  const CredentialMigrationResult({
    required this.status,
    required this.safeMessage,
  });

  final CredentialMigrationStatus status;
  final String safeMessage;

  bool get failed => status == CredentialMigrationStatus.failed;
}

typedef LegacyCredentialReader = Object? Function(String key);
typedef LegacyCredentialRemover = Future<void> Function(String key);

class DandanplayCredentialMigrator {
  DandanplayCredentialMigrator({
    required DanmakuCredentialStore store,
    required LegacyCredentialReader readLegacy,
    required LegacyCredentialRemover removeLegacy,
  })  : _store = store,
        _readLegacy = readLegacy,
        _removeLegacy = removeLegacy;

  static const legacyAppIdKey = 'dandanplay_app_id';
  static const legacyAppSecretKey = 'dandanplay_app_secret';

  final DanmakuCredentialStore _store;
  final LegacyCredentialReader _readLegacy;
  final LegacyCredentialRemover _removeLegacy;

  Future<CredentialMigrationResult> migrateLegacyHiveCredentials() async {
    try {
      final secure = await _store.read();
      if (secure?.isValid ?? false) {
        await _removeLegacyCredentials();
        return const CredentialMigrationResult(
          status: CredentialMigrationStatus.alreadySecure,
          safeMessage: '安全凭据已可用，旧明文凭据已清理。',
        );
      }

      final appId = _readLegacy(legacyAppIdKey)?.toString().trim() ?? '';
      final appSecret =
          _readLegacy(legacyAppSecretKey)?.toString().trim() ?? '';
      if (appId.isEmpty && appSecret.isEmpty) {
        return const CredentialMigrationResult(
          status: CredentialMigrationStatus.noLegacyCredentials,
          safeMessage: '没有需要迁移的旧凭据。',
        );
      }
      if (appId.isEmpty || appSecret.isEmpty) {
        return const CredentialMigrationResult(
          status: CredentialMigrationStatus.failed,
          safeMessage: '旧凭据不完整，已保留原数据，请重新填写后重试。',
        );
      }

      final credentials = DandanplayCredentials(
        appId: appId,
        appSecret: appSecret,
      );
      await _store.write(credentials);
      final verified = await _store.read();
      if (verified?.appId != credentials.appId ||
          verified?.appSecret != credentials.appSecret) {
        return const CredentialMigrationResult(
          status: CredentialMigrationStatus.failed,
          safeMessage: '安全凭据回读校验失败，旧数据已保留。',
        );
      }

      await _removeLegacyCredentials();
      return const CredentialMigrationResult(
        status: CredentialMigrationStatus.migrated,
        safeMessage: '弹弹play凭据已迁移到 Windows 凭据管理器。',
      );
    } catch (_) {
      return const CredentialMigrationResult(
        status: CredentialMigrationStatus.failed,
        safeMessage: '安全迁移失败，旧数据已保留，可稍后重试。',
      );
    }
  }

  Future<void> _removeLegacyCredentials() async {
    await _removeLegacy(legacyAppIdKey);
    await _removeLegacy(legacyAppSecretKey);
  }
}
