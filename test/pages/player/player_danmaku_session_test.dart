import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:weila/models/danmaku_item.dart';
import 'package:weila/pages/player/player_danmaku_session.dart';
import 'package:weila/services/danmaku/danmaku_load_result.dart';
import 'package:weila/services/danmaku/danmaku_matcher.dart';
import 'package:weila/widgets/danmaku_overlay.dart';

void main() {
  test('latest load generation wins and stale response is ignored', () async {
    final gateway = _FakeGateway();
    final controller = DanmakuController();
    final session = PlayerDanmakuSession(
      gateway: gateway,
      controller: controller,
    );

    final first = session.load(anime: '作品 A', episode: 1);
    final second = session.load(anime: '作品 B', episode: 2);
    expect(session.result.status, DanmakuLoadStatus.searching);

    gateway.loads[1].complete(_loaded('second'));
    await second;
    expect(session.result.items.single.text, 'second');
    expect(controller.allDanmaku.single.text, 'second');

    gateway.loads[0].complete(_loaded('stale'));
    await first;
    expect(session.result.items.single.text, 'second');
    expect(controller.allDanmaku.single.text, 'second');

    session.dispose();
  });

  test('load exposes not configured state before gateway response', () async {
    final gateway = _FakeGateway(hasCredentials: false);
    final session = PlayerDanmakuSession(
      gateway: gateway,
      controller: DanmakuController(),
    );

    final pending = session.load(anime: '作品', episode: 1);

    expect(session.result.status, DanmakuLoadStatus.notConfigured);
    gateway.loads.single.complete(
      DanmakuLoadResult(status: DanmakuLoadStatus.notConfigured),
    );
    await pending;
    session.dispose();
  });

  test('choose publishes loading state and applies selected result', () async {
    const candidate = DanmakuMatchCandidate(
      animeId: 1,
      animeTitle: '作品',
      typeDescription: 'TV',
      episodeId: 11,
      episodeTitle: '第1话',
      score: 100,
    );
    final gateway = _FakeGateway();
    final session = PlayerDanmakuSession(
      gateway: gateway,
      controller: DanmakuController(),
    );

    final pending = session.choose(
      anime: '作品',
      episode: 1,
      candidate: candidate,
    );

    expect(session.result.status, DanmakuLoadStatus.loading);
    expect(session.result.selected, candidate);
    gateway.choices.single.complete(_loaded('chosen'));
    await pending;
    expect(session.result.items.single.text, 'chosen');
    session.dispose();
  });
}

DanmakuLoadResult _loaded(String text) {
  return DanmakuLoadResult(
    status: DanmakuLoadStatus.loaded,
    items: [DanmakuItem(text: text, time: 1)],
  );
}

class _FakeGateway implements PlayerDanmakuGateway {
  _FakeGateway({this.hasCredentials = true});

  @override
  final bool hasCredentials;
  final List<Completer<DanmakuLoadResult>> loads = [];
  final List<Completer<DanmakuLoadResult>> choices = [];

  @override
  Future<DanmakuLoadResult> choose({
    required String anime,
    required int episode,
    required DanmakuMatchCandidate candidate,
  }) {
    final completer = Completer<DanmakuLoadResult>();
    choices.add(completer);
    return completer.future;
  }

  @override
  Future<DanmakuLoadResult> load({
    required String anime,
    required int episode,
    bool refresh = false,
  }) {
    final completer = Completer<DanmakuLoadResult>();
    loads.add(completer);
    return completer.future;
  }
}
