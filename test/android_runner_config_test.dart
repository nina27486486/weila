import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final gradle = File('android/app/build.gradle.kts');
  final manifest = File('android/app/src/main/AndroidManifest.xml');
  final network =
      File('android/app/src/main/res/xml/network_security_config.xml');
  final extraction =
      File('android/app/src/main/res/xml/data_extraction_rules.xml');

  test('Android runner pins the approved SDK and application identity', () {
    final source = gradle.readAsStringSync();
    expect(source, contains('namespace = "io.github.nina27486486.weila"'));
    expect(source, contains('applicationId = "io.github.nina27486486.weila"'));
    expect(source, contains('compileSdk = 36'));
    expect(source, contains('minSdk = 24'));
    expect(source, contains('targetSdk = 36'));
    expect(source, contains('JavaVersion.VERSION_17'));
    expect(source, isNot(contains('signingConfigs.getByName("debug")')));
  });

  test('Android manifest keeps network and backup policy restrictive', () {
    final source = manifest.readAsStringSync();
    expect(source, contains('android.permission.INTERNET'));
    expect(source, contains('android:usesCleartextTraffic="false"'));
    expect(source, contains('android:allowBackup="false"'));
    expect(
      source,
      contains('android:dataExtractionRules="@xml/data_extraction_rules"'),
    );
    expect(
      source,
      contains('android:networkSecurityConfig="@xml/network_security_config"'),
    );
    expect(
      network.readAsStringSync(),
      contains('cleartextTrafficPermitted="false"'),
    );
    expect(
      extraction.readAsStringSync(),
      contains('<exclude domain="database" path="."/>'),
    );
    expect(
      extraction.readAsStringSync(),
      contains('<exclude domain="sharedpref" path="."/>'),
    );
  });

  test('Android signing material remains outside the repository', () {
    expect(File('android/key.properties').existsSync(), isFalse);
    expect(
      Directory('android')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) =>
              file.path.endsWith('.jks') || file.path.endsWith('.keystore')),
      isEmpty,
    );
  });
}
