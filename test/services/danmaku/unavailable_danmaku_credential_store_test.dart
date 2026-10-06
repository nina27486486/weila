import 'package:flutter_test/flutter_test.dart';
import 'package:weila/services/danmaku/dandanplay_credential_manager.dart';
import 'package:weila/services/danmaku/unavailable_danmaku_credential_store.dart';

void main() {
  const store = UnavailableDanmakuCredentialStore();

  test('unavailable store fails closed without returning plaintext', () async {
    await expectLater(store.read(), throwsA(isA<UnsupportedError>()));
    await expectLater(store.clear(), throwsA(isA<UnsupportedError>()));
  });

  test('manager turns unavailable storage into a safe retry state', () async {
    var legacyReads = 0;
    var clearCalls = 0;
    final manager = DanmakuCredentialManager.testing(
      store: store,
      readLegacy: (_) {
        legacyReads++;
        return 'must-not-be-read';
      },
      removeLegacy: (_) async {},
      applyCredentials: (_) => fail('unavailable credentials cannot apply'),
      clearCredentials: () => clearCalls++,
    );

    final result = await manager.initialize();

    expect(result.failed, isTrue);
    expect(result.safeMessage, isNot(contains('UnsupportedError')));
    expect(legacyReads, 0);
    expect(clearCalls, 1);
  });
}
