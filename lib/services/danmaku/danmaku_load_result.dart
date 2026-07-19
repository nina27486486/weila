import '../../models/danmaku_item.dart';
import 'danmaku_diagnostics.dart';
import 'danmaku_matcher.dart';

enum DanmakuLoadStatus {
  notConfigured,
  searching,
  ambiguous,
  loading,
  loaded,
  noMatch,
  authFailed,
  quotaExceeded,
  networkFailed,
  malformedResponse,
}

class DanmakuLoadResult {
  DanmakuLoadResult({
    required this.status,
    Iterable<DanmakuMatchCandidate> candidates =
        const <DanmakuMatchCandidate>[],
    this.selected,
    Iterable<DanmakuItem> items = const <DanmakuItem>[],
    this.fromCache = false,
    this.safeMessage,
    this.diagnostics = DanmakuLoadDiagnostics.empty,
  })  : candidates = List<DanmakuMatchCandidate>.unmodifiable(candidates),
        items = List<DanmakuItem>.unmodifiable(items);

  final DanmakuLoadStatus status;
  final List<DanmakuMatchCandidate> candidates;
  final DanmakuMatchCandidate? selected;
  final List<DanmakuItem> items;
  final bool fromCache;
  final String? safeMessage;
  final DanmakuLoadDiagnostics diagnostics;

  bool get retryable =>
      status == DanmakuLoadStatus.networkFailed ||
      status == DanmakuLoadStatus.noMatch;
}
