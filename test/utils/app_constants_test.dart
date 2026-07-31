import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:weila/utils/constants.dart';

void main() {
  test('runtime semantic version matches pubspec', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final match = RegExp(
      r'^version:\s*(\d+\.\d+\.\d+)(?:\+\d+)?\s*$',
      multiLine: true,
    ).firstMatch(pubspec);

    expect(match, isNotNull);
    expect(AppConstants.appVersion, match!.group(1));
  });

  test('release update URL points to the latest GitHub release', () {
    final uri = Uri.parse(AppConstants.releaseUpdatesUrl);

    expect(uri.scheme, 'https');
    expect(uri.host, 'github.com');
    expect(uri.path, '/nina27486486/weila/releases/latest');
  });
}
