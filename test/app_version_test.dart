import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:weila/utils/constants.dart';

void main() {
  test('应用版本常量与 pubspec 保持一致', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final versionMatch = RegExp(
      r'^version:\s*([0-9]+\.[0-9]+\.[0-9]+)(?:\+\d+)?\s*$',
      multiLine: true,
    ).firstMatch(pubspec);

    expect(versionMatch, isNotNull);
    expect(AppConstants.appVersion, versionMatch!.group(1));
  });
}
