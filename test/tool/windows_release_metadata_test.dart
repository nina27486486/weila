import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Windows executable resource uses official Weila metadata', () {
    final resource = File('windows/runner/Runner.rc').readAsStringSync();

    expect(resource, isNot(contains('com.example')));
    expect(resource, contains('VALUE "CompanyName", "Weila"'));
    expect(resource, contains('VALUE "FileDescription", "Weila"'));
    expect(resource, contains('VALUE "InternalName", "weila"'));
    expect(resource, contains('VALUE "OriginalFilename", "weila.exe"'));
    expect(resource, contains('VALUE "ProductName", "Weila"'));
    expect(resource, contains('VERSION_AS_NUMBER'));
    expect(resource, contains('VERSION_AS_STRING'));
  });
}
