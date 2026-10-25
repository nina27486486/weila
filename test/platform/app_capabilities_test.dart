import 'package:flutter_test/flutter_test.dart';
import 'package:weila/platform/app_capabilities.dart';

void main() {
  test('Windows keeps desktop capabilities', () {
    expect(AppCapabilities.windows.downloads, isTrue);
    expect(AppCapabilities.windows.pluginEditing, isTrue);
    expect(AppCapabilities.windows.secureCredentialStorage, isTrue);
  });

  test('Android compile baseline fails closed for unsupported features', () {
    const capabilities = AppCapabilities.androidCompileBaseline;
    expect(capabilities.downloads, isFalse);
    expect(capabilities.pluginEditing, isFalse);
  });

  test('Android baseline enables secure credential storage', () {
    // AndroidDanmakuCredentialStore 已接入 Android Keystore 加密存储。
    expect(
      AppCapabilities.androidCompileBaseline.secureCredentialStorage,
      isTrue,
    );
  });
}
