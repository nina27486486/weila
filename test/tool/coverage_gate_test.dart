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
SF:lib/widgets/score_badge.dart
DA:1,1
end_of_record
SF:lib/pages/home/home_page.dart
DA:1,1
DA:2,0
DA:3,1
end_of_record
''';

  test('parses overall and release-critical module coverage', () {
    final report = CoverageReport.parse(lcov);

    // 页面组合层不计入全仓口径（由真机/集成验收把关）。
    expect(report.overall.found, 5);
    expect(report.overall.hit, 4);
    expect(report.overall.percent, 80);
    expect(report.releaseCritical.found, 4);
    expect(report.releaseCritical.hit, 3);
    expect(report.releaseCritical.percent, 75);
  });

  test('page composition files stay out of the overall denominator', () {
    final report = CoverageReport.parse(lcov);

    // lib/pages/home/home_page.dart 的 3 行（含 1 次零命中）不进分母。
    expect(report.overall.found, isNot(7));
  });

  test('evaluates both overall and release-critical thresholds', () {
    final report = CoverageReport.parse(lcov);

    expect(
      report.evaluate(overallMinimum: 70, releaseCriticalMinimum: 75).passed,
      isTrue,
    );
    final failed = report.evaluate(
      overallMinimum: 101,
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
