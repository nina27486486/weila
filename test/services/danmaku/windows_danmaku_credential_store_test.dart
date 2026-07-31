@TestOn('windows')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:weila/services/danmaku/dandanplay_credentials.dart';
import 'package:weila/services/danmaku/windows_danmaku_credential_store.dart';

void main() {
  final target = 'Weila.Tests/${DateTime.now().microsecondsSinceEpoch}';
  final store = WindowsDanmakuCredentialStore(targetName: target);

  tearDown(() async => store.clear());

  test('writes reads updates and deletes a generic Windows credential',
      () async {
    await store.write(
      const DandanplayCredentials(
        appId: 'integration-app',
        appSecret: 'integration-secret',
      ),
    );

    expect((await store.read())?.appId, 'integration-app');
    expect((await store.read())?.appSecret, 'integration-secret');

    await store.write(
      const DandanplayCredentials(
        appId: 'updated-app',
        appSecret: 'updated-secret',
      ),
    );
    expect((await store.read())?.appId, 'updated-app');

    await store.clear();
    expect(await store.read(), isNull);
  });
}
