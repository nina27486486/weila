import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'danmaku_credential_store.dart';
import 'dandanplay_credentials.dart';

/// Android 安全凭据存储（MVP 计划 §3）。
///
/// flutter_secure_storage 在 Android 上默认走 Android Keystore 加密
/// （RSA-OAEP + AES-GCM 的 EncryptedSharedPreferences 族实现）；
/// 生产环境不回退 Hive 明文。存储注入以便单元测试替换。
class AndroidDanmakuCredentialStore implements DanmakuCredentialStore {
  AndroidDanmakuCredentialStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _appIdKey = 'weila.dandanplay.appId';
  static const _appSecretKey = 'weila.dandanplay.appSecret';

  final FlutterSecureStorage _storage;

  @override
  Future<DandanplayCredentials?> read() async {
    final appId = await _storage.read(key: _appIdKey);
    final appSecret = await _storage.read(key: _appSecretKey);
    if (appId == null || appSecret == null) return null;
    final credentials = DandanplayCredentials(
      appId: appId,
      appSecret: appSecret,
    );
    // 与 Windows 实现一致：损坏的存量数据视为无凭据。
    return credentials.isValid ? credentials : null;
  }

  @override
  Future<void> write(DandanplayCredentials credentials) async {
    await _storage.write(key: _appIdKey, value: credentials.appId);
    await _storage.write(key: _appSecretKey, value: credentials.appSecret);
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _appIdKey);
    await _storage.delete(key: _appSecretKey);
  }
}
