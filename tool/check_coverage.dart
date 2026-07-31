import 'dart:io';

import 'coverage_gate.dart';

void main(List<String> arguments) {
  final options = _parseArguments(arguments);
  final file = File(options.file);
  if (!file.existsSync()) {
    stderr.writeln('Coverage gate: 未找到 ${options.file}');
    exitCode = 2;
    return;
  }

  try {
    final report = CoverageReport.parse(file.readAsStringSync());
    final result = report.evaluate(
      overallMinimum: options.overallMinimum,
      releaseCriticalMinimum: options.releaseCriticalMinimum,
    );
    stdout.writeln('Coverage gate: ${result.safeSummary}');
    if (!result.passed) exitCode = 1;
  } on FormatException catch (error) {
    stderr.writeln('Coverage gate: ${error.message}');
    exitCode = 2;
  }
}

_CoverageOptions _parseArguments(List<String> arguments) {
  var file = 'coverage/lcov.info';
  var overallMinimum = 70.0;
  var releaseCriticalMinimum = 85.0;

  for (var index = 0; index < arguments.length; index++) {
    final argument = arguments[index];
    if (index + 1 >= arguments.length) {
      throw FormatException('参数 $argument 缺少值。');
    }
    final value = arguments[++index];
    switch (argument) {
      case '--file':
        file = value;
      case '--overall':
        overallMinimum = _parsePercent(value, argument);
      case '--critical':
        releaseCriticalMinimum = _parsePercent(value, argument);
      default:
        throw FormatException('未知参数：$argument');
    }
  }
  return _CoverageOptions(
    file: file,
    overallMinimum: overallMinimum,
    releaseCriticalMinimum: releaseCriticalMinimum,
  );
}

double _parsePercent(String value, String argument) {
  final parsed = double.tryParse(value);
  if (parsed == null || parsed < 0 || parsed > 100) {
    throw FormatException('$argument 必须是 0 到 100 的数字。');
  }
  return parsed;
}

class _CoverageOptions {
  const _CoverageOptions({
    required this.file,
    required this.overallMinimum,
    required this.releaseCriticalMinimum,
  });

  final String file;
  final double overallMinimum;
  final double releaseCriticalMinimum;
}
