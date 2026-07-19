import 'package:flutter_test/flutter_test.dart';
import 'package:weila/debug/danmaku_debug_session.dart';
import 'package:weila/debug/fake_player.dart';
import 'package:weila/models/danmaku_item.dart';
import 'package:weila/services/danmaku/danmaku_diagnostics.dart';
import 'package:weila/services/danmaku/danmaku_load_result.dart';
import 'package:weila/services/danmaku/danmaku_matcher.dart';
import 'package:weila/widgets/danmaku_overlay.dart';

void main() {
  test('combines acquisition, queue, and fake timeline diagnostics', () async {
    final ticker = _ManualTicker();
    final player = FakePlayer(ticker: ticker);
    final controller = DanmakuController();
    final source = _FakeSource(
      DanmakuLoadResult(
        status: DanmakuLoadStatus.loaded,
        selected: _candidate,
        items: [
          DanmakuItem(text: 'sensitive comment', time: 0),
          DanmakuItem(text: 'another comment', time: 0.5),
        ],
        diagnostics: const DanmakuLoadDiagnostics(
          episodeId: 3456,
          commentCount: 3,
          parsedCount: 2,
        ),
      ),
    );
    final session = DanmakuDebugSession(
      source: source,
      player: player,
      controller: controller,
    );

    await session.load(anime: 'Test Anime', episode: 1);
    player.play();
    ticker.elapse(const Duration(milliseconds: 600));

    final snapshot = session.snapshot;
    expect(snapshot.episodeId, 3456);
    expect(snapshot.commentCount, 3);
    expect(snapshot.parsedCount, 2);
    expect(snapshot.queuedCount, 2);
    expect(snapshot.currentTime, 0.6);
    expect(snapshot.errorStage, DanmakuErrorStage.none);
    expect(snapshot.danmakuEnabled, isTrue);
    expect(snapshot.opacity, 1);
    expect(snapshot.area, 1);
    expect(snapshot.toSafeText(), contains('episodeId: 3456'));
    expect(snapshot.toSafeText(), isNot(contains('sensitive comment')));
  });

  test('preserves candidates and loads the explicitly selected episode',
      () async {
    final ambiguous = DanmakuLoadResult(
      status: DanmakuLoadStatus.ambiguous,
      candidates: [_candidate, _candidateTwo],
      diagnostics: const DanmakuLoadDiagnostics(
        errorStage: DanmakuErrorStage.match,
      ),
    );
    final selected = DanmakuLoadResult(
      status: DanmakuLoadStatus.loaded,
      selected: _candidateTwo,
      items: [DanmakuItem(text: 'chosen', time: 1)],
      diagnostics: const DanmakuLoadDiagnostics(
        episodeId: 6789,
        commentCount: 1,
        parsedCount: 1,
      ),
    );
    final source = _FakeSource(ambiguous, chosenResult: selected);
    final session = DanmakuDebugSession(
      source: source,
      player: FakePlayer(ticker: _ManualTicker()),
      controller: DanmakuController(),
    );

    await session.load(anime: 'Test Anime', episode: 1);
    expect(session.candidates, hasLength(2));
    expect(session.snapshot.errorStage, DanmakuErrorStage.match);

    await session.choose(_candidateTwo);
    expect(source.chosen, _candidateTwo);
    expect(session.candidates, isEmpty);
    expect(session.snapshot.episodeId, 6789);
    expect(session.snapshot.queuedCount, 1);
    expect(session.snapshot.errorStage, DanmakuErrorStage.none);
  });
}

const _candidate = DanmakuMatchCandidate(
  animeId: 1,
  animeTitle: 'Test Anime',
  typeDescription: 'TV',
  episodeId: 3456,
  episodeTitle: 'Episode 1',
  score: 100,
);

const _candidateTwo = DanmakuMatchCandidate(
  animeId: 2,
  animeTitle: 'Test Anime 2',
  typeDescription: 'TV',
  episodeId: 6789,
  episodeTitle: 'Episode 1',
  score: 90,
);

class _FakeSource implements DanmakuDebugSource {
  _FakeSource(this.result, {this.chosenResult});

  final DanmakuLoadResult result;
  final DanmakuLoadResult? chosenResult;
  DanmakuMatchCandidate? chosen;

  @override
  Future<DanmakuLoadResult> load({
    required String anime,
    required int episode,
    bool refresh = false,
  }) async =>
      result;

  @override
  Future<DanmakuLoadResult> choose({
    required String anime,
    required int episode,
    required DanmakuMatchCandidate candidate,
  }) async {
    chosen = candidate;
    return chosenResult ?? result;
  }
}

class _ManualTicker implements LocalTimelineTicker {
  void Function(Duration delta)? _onTick;

  @override
  void start(void Function(Duration delta) onTick) => _onTick = onTick;

  void elapse(Duration delta) => _onTick?.call(delta);

  @override
  void stop() => _onTick = null;

  @override
  void dispose() => stop();
}
