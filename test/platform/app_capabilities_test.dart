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
    expect(capabilities.secureCredentialStorage, isFalse);
  });
}
