import 'dandanplay_credentials.dart';

abstract interface class DanmakuCredentialStore {
  Future<DandanplayCredentials?> read();

  Future<void> write(DandanplayCredentials credentials);

  Future<void> clear();
}
