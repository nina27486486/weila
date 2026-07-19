import 'package:flutter_test/flutter_test.dart';
import 'package:weila/services/danmaku/danmaku_credential_draft.dart';

void main() {
  test('never exposes the stored secret as initial editable text', () {
    const draft = DanmakuCredentialDraft(
      storedAppId: 'app-id',
      storedAppSecret: 'stored-secret',
    );

    expect(draft.initialAppId, 'app-id');
    expect(draft.initialSecret, isEmpty);
    expect(draft.secretHint, contains('已保存'));
  });

  test('blank secret keeps the stored value while a new value replaces it', () {
    const draft = DanmakuCredentialDraft(
      storedAppId: 'app-id',
      storedAppSecret: 'stored-secret',
    );

    expect(draft.resolveSecret('   '), 'stored-secret');
    expect(draft.resolveSecret(' new-secret '), 'new-secret');
  });
}
