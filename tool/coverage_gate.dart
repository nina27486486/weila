class CoverageMetrics {
  const CoverageMetrics({
    required this.found,
    required this.hit,
  });

  final int found;
  final int hit;

  double get percent => found == 0 ? 0 : hit * 100 / found;
}

class CoverageGateResult {
  const CoverageGateResult({
    required this.passed,
    required this.safeSummary,
  });

  final bool passed;
  final String safeSummary;
}

class CoverageReport {
  const CoverageReport({
    required this.overall,
    required this.releaseCritical,
  });

  final CoverageMetrics overall;
  final CoverageMetrics releaseCritical;

  factory CoverageReport.parse(String lcov) {
    var currentSource = '';
    final allLines = <String, Map<int, int>>{};

    for (final rawLine in lcov.split(RegExp(r'\r?\n'))) {
      final line = rawLine.trim();
      if (line.startsWith('SF:')) {
        currentSource = _normalizePath(line.substring(3));
        allLines.putIfAbsent(currentSource, () => <int, int>{});
        continue;
      }
      if (!line.startsWith('DA:') || currentSource.isEmpty) continue;

      final fields = line.substring(3).split(',');
      if (fields.length < 2) {
        throw const FormatException('LCOV DA 记录格式无效。');
      }
      final lineNumber = int.tryParse(fields[0]);
      final hitCount = int.tryParse(fields[1]);
      if (lineNumber == null || hitCount == null) {
        throw const FormatException('LCOV DA 记录包含无效数字。');
      }
      final sourceLines = allLines[currentSource]!;
      sourceLines[lineNumber] = (sourceLines[lineNumber] ?? 0) + hitCount;
    }

    final all = _summarize(allLines.entries);
    if (all.found == 0) {
      throw const FormatException('LCOV 中没有可统计的 Dart 行覆盖数据。');
    }
    final critical = _summarize(
      allLines.entries.where((entry) => _isReleaseCritical(entry.key)),
    );
    if (critical.found == 0) {
      throw const FormatException('LCOV 中没有发布关键模块覆盖数据。');
    }
    return CoverageReport(overall: all, releaseCritical: critical);
  }

  CoverageGateResult evaluate({
    required double overallMinimum,
    required double releaseCriticalMinimum,
  }) {
    final overallPassed = overall.percent >= overallMinimum;
    final criticalPassed = releaseCritical.percent >= releaseCriticalMinimum;
    return CoverageGateResult(
      passed: overallPassed && criticalPassed,
      safeSummary: [
        '全仓 ${overall.percent.toStringAsFixed(2)}% '
            '(要求 ≥ ${overallMinimum.toStringAsFixed(2)}%)',
        '发布关键模块 ${releaseCritical.percent.toStringAsFixed(2)}% '
            '(要求 ≥ ${releaseCriticalMinimum.toStringAsFixed(2)}%)',
      ].join('；'),
    );
  }

  static CoverageMetrics _summarize(
    Iterable<MapEntry<String, Map<int, int>>> sources,
  ) {
    var found = 0;
    var hit = 0;
    for (final source in sources) {
      found += source.value.length;
      hit += source.value.values.where((count) => count > 0).length;
    }
    return CoverageMetrics(found: found, hit: hit);
  }

  static bool _isReleaseCritical(String path) {
    return path.contains('/lib/services/diagnostics/') ||
        path.startsWith('lib/services/diagnostics/') ||
        path.toLowerCase().contains('credential');
  }

  static String _normalizePath(String path) => path.replaceAll(r'\', '/');
}
