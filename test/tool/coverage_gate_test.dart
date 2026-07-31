import 'package:flutter_test/flutter_test.dart';

import '../../tool/coverage_gate.dart';

void main() {
  const lcov = '''
SF:lib/services/diagnostics/report.dart
DA:1,1
DA:2,0
end_of_record
SF:lib/services/danmaku/dandanplay_credential_manager.dart
DA:1,1
DA:2,1
end_of_record
SF:lib/pages/home/home_page.dart
DA:1,1
DA:2,0
DA:3,1
end_of_record
''';

  test('parses overall and release-critical module coverage', () {
    final report = CoverageReport.parse(lcov);

    expect(report.overall.found, 7);
    expect(report.overall.hit, 5);
    expect(report.overall.percent, closeTo(71.42, 0.01));
    expect(report.releaseCritical.found, 4);
    expect(report.releaseCritical.hit, 3);
    expect(report.releaseCritical.percent, 75);
  });

  test('evaluates both overall and release-critical thresholds', () {
    final report = CoverageReport.parse(lcov);

    expect(
      report.evaluate(overallMinimum: 70, releaseCriticalMinimum: 75).passed,
      isTrue,
    );
    final failed = report.evaluate(
      overallMinimum: 72,
      releaseCriticalMinimum: 85,
    );
    expect(failed.passed, isFalse);
    expect(failed.safeSummary, contains('全仓'));
    expect(failed.safeSummary, contains('发布关键模块'));
  });

  test('rejects malformed or empty lcov input', () {
    expect(() => CoverageReport.parse(''), throwsFormatException);
    expect(
      () => CoverageReport.parse('SF:lib/a.dart\nend_of_record'),
      throwsFormatException,
    );
  });
}
