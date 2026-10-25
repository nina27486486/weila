import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weila/services/danmaku/android_danmaku_credential_store.dart';
import 'package:weila/services/danmaku/dandanplay_credentials.dart';

/// 内存版安全存储：覆写 flutter_secure_storage 的读写删除，
/// 不触平台通道。
class _InMemorySecureStorage extends FlutterSecureStorage {
  final Map<String, String> _values = {};

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async =>
      _values[key];

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _values[key] = value ?? '';
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _values.remove(key);
  }
}

void main() {
  test('写入后能读回一致且有效的凭据', () async {
    final storage = _InMemorySecureStorage();
    final store = AndroidDanmakuCredentialStore(storage: storage);

    await store.write(
      const DandanplayCredentials(appId: 'app-id-1', appSecret: 'secret-1'),
    );

    final read = await store.read();
    expect(read, isNotNull);
    expect(read!.appId, 'app-id-1');
    expect(read.appSecret, 'secret-1');
    expect(read.isValid, isTrue);
  });

  test('未写入时读取返回 null', () async {
    final store = AndroidDanmakuCredentialStore(
      storage: _InMemorySecureStorage(),
    );
    expect(await store.read(), isNull);
  });

  test('clear 后凭据不可读', () async {
    final storage = _InMemorySecureStorage();
    final store = AndroidDanmakuCredentialStore(storage: storage);
    await store.write(
      const DandanplayCredentials(appId: 'app-id-2', appSecret: 'secret-2'),
    );

    await store.clear();

    expect(await store.read(), isNull);
  });

  test('损坏的存量数据（无效凭据）视为无凭据', () async {
    final storage = _InMemorySecureStorage();
    await storage.write(key: 'weila.dandanplay.appId', value: '');
    await storage.write(key: 'weila.dandanplay.appSecret', value: '   ');
    final store = AndroidDanmakuCredentialStore(storage: storage);

    expect(await store.read(), isNull);
  });

  test('只存在一半键时视为无凭据', () async {
    final storage = _InMemorySecureStorage();
    await storage.write(key: 'weila.dandanplay.appId', value: 'app-id-3');
    final store = AndroidDanmakuCredentialStore(storage: storage);

    expect(await store.read(), isNull);
  });
}
