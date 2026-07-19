import 'package:flutter_test/flutter_test.dart';
import 'package:weila/models/danmaku_item.dart';
import 'package:weila/services/danmaku/danmaku_load_result.dart';
import 'package:weila/services/danmaku/danmaku_matcher.dart';

void main() {
  const candidate = DanmakuMatchCandidate(
    animeId: 1,
    animeTitle: '测试动画',
    typeDescription: 'TV动画',
    episodeId: 10001,
    episodeTitle: '第1话',
    score: 100,
  );

  test('defensively freezes candidates and danmaku items', () {
    final candidates = <DanmakuMatchCandidate>[candidate];
    final items = <DanmakuItem>[
      DanmakuItem(text: '弹幕', time: 1),
    ];
    final result = DanmakuLoadResult(
      status: DanmakuLoadStatus.loaded,
      candidates: candidates,
      selected: candidate,
      items: items,
      fromCache: true,
    );
    candidates.clear();
    items.clear();

    expect(result.candidates, hasLength(1));
    expect(result.items, hasLength(1));
    expect(() => result.items.add(DanmakuItem(text: 'x', time: 2)),
        throwsUnsupportedError);
    expect(result.fromCache, isTrue);
  });

  test('only retryable states expose retry behavior', () {
    DanmakuLoadResult state(DanmakuLoadStatus status) =>
        DanmakuLoadResult(status: status);

    expect(state(DanmakuLoadStatus.networkFailed).retryable, isTrue);
    expect(state(DanmakuLoadStatus.noMatch).retryable, isTrue);
    expect(state(DanmakuLoadStatus.authFailed).retryable, isFalse);
    expect(state(DanmakuLoadStatus.quotaExceeded).retryable, isFalse);
    expect(state(DanmakuLoadStatus.malformedResponse).retryable, isFalse);
    expect(state(DanmakuLoadStatus.loaded).retryable, isFalse);
  });
}
