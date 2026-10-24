import 'dandanplay_credentials.dart';
import 'danmaku_credential_store.dart';

class UnavailableDanmakuCredentialStore implements DanmakuCredentialStore {
  const UnavailableDanmakuCredentialStore();

  Never _fail() => throw UnsupportedError('安全凭据存储在当前平台暂不可用。');

  @override
  Future<DandanplayCredentials?> read() async => _fail();

  @override
  Future<void> write(DandanplayCredentials credentials) async => _fail();

  @override
  Future<void> clear() async => _fail();
}
