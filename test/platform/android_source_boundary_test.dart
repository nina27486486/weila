import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android entry imports no Windows implementation or download service',
      () {
    final source = File('lib/main_android.dart').readAsStringSync();
    for (final forbidden in [
      'package:window_manager',
      'package:win32',
      'windows_danmaku_credential_store',
      'DownloadService',
    ]) {
      expect(source, isNot(contains(forbidden)), reason: forbidden);
    }
  });

  test('shared startup and credential manager have no Windows imports', () {
    final sources = [
      File('lib/bootstrap/app_bootstrap.dart').readAsStringSync(),
      File('lib/services/danmaku/dandanplay_credential_manager.dart')
          .readAsStringSync(),
    ].join('\n');
    expect(sources, isNot(contains('package:window_manager')));
    expect(sources, isNot(contains('package:win32')));
    expect(sources, isNot(contains('windows_danmaku_credential_store')));
  });
}
