import 'package:flutter_test/flutter_test.dart';
import 'package:weila/services/danmaku/danmaku_matcher.dart';

Map<String, dynamic> _response(List<Map<String, dynamic>> animes) => {
      'success': true,
      'animes': animes,
    };

Map<String, dynamic> _anime({
  required int animeId,
  required String title,
  String type = 'TV动画',
  required List<Map<String, dynamic>> episodes,
}) {
  return {
    'animeId': animeId,
    'animeTitle': title,
    'typeDescription': type,
    'episodes': episodes,
  };
}

Map<String, dynamic> _episode(int id, String title) => {
      'episodeId': id,
      'episodeTitle': title,
    };

void main() {
  const matcher = DanmakuMatcher();

  test('auto-selects an exact normalized title and episode', () {
    final decision = matcher.match(
      requestedAnime: '葬送的芙莉莲',
      requestedEpisode: 1,
      response: _response([
        _anime(
          animeId: 100,
          title: '葬送的芙莉莲',
          episodes: [_episode(10001, '第1话')],
        ),
      ]),
    );

    expect(decision.selected, isNotNull);
    expect(decision.selected!.episodeId, 10001);
    expect(decision.selected!.score, 100);
    expect(decision.ambiguous, isFalse);
  });

  test('normalizes full-width latin punctuation spaces and case', () {
    final decision = matcher.match(
      requestedAnime: 'SPY×FAMILY Part 2',
      requestedEpisode: 3,
      response: _response([
        _anime(
          animeId: 200,
          title: 'ＳＰＹ × ＦＡＭＩＬＹ　ＰＡＲＴ ２',
          episodes: [_episode(20003, 'Episode 3')],
        ),
      ]),
    );

    expect(decision.selected?.episodeId, 20003);
    expect(decision.selected?.score, 100);
  });

  test('matches a trailing numeric sequel to the equivalent Chinese season',
      () {
    final decision = matcher.match(
      requestedAnime: '幼女战记2',
      requestedEpisode: 1,
      response: _response([
        _anime(
          animeId: 210,
          title: '幼女战记 第二季',
          episodes: [_episode(21001, '第1话')],
        ),
      ]),
    );

    expect(decision.selected?.episodeId, 21001);
    expect(decision.selected?.score, 100);
  });

  test('ignores the decorative infinity mark in YUME MITA titles', () {
    final decision = matcher.match(
      requestedAnime: 'banGDream! YUME-MITA',
      requestedEpisode: 1,
      response: _response([
        _anime(
          animeId: 220,
          title: 'BanG Dream! YUME∞MITA',
          episodes: [_episode(22001, 'Episode 1')],
        ),
      ]),
    );

    expect(decision.selected?.episodeId, 22001);
    expect(decision.selected?.score, 100);
  });

  test('episode one never matches episode ten or eleven', () {
    final decision = matcher.match(
      requestedAnime: '测试动画',
      requestedEpisode: 1,
      response: _response([
        _anime(
          animeId: 300,
          title: '测试动画',
          episodes: [
            _episode(30010, '第10话'),
            _episode(30011, '第11话'),
            _episode(30001, '第1话'),
          ],
        ),
      ]),
    );

    expect(decision.candidates.map((item) => item.episodeId), [30001]);
    expect(decision.selected?.episodeId, 30001);
  });

  test('prefers exact season and penalizes conflicting season tokens', () {
    final decision = matcher.match(
      requestedAnime: '无职转生 第二季',
      requestedEpisode: 1,
      response: _response([
        _anime(
          animeId: 401,
          title: '无职转生',
          episodes: [_episode(40101, '第1话')],
        ),
        _anime(
          animeId: 402,
          title: '无职转生 第二季',
          episodes: [_episode(40201, '第1话')],
        ),
      ]),
    );

    expect(decision.selected?.animeId, 402);
    expect(decision.candidates.first.score,
        greaterThan(decision.candidates.last.score));
  });

  test('equal top candidates stay ambiguous in response order', () {
    final decision = matcher.match(
      requestedAnime: '同名动画',
      requestedEpisode: 1,
      response: _response([
        _anime(
          animeId: 501,
          title: '同名动画',
          episodes: [_episode(50101, '第1话')],
        ),
        _anime(
          animeId: 502,
          title: '同名动画',
          episodes: [_episode(50201, '第1话')],
        ),
      ]),
    );

    expect(decision.ambiguous, isTrue);
    expect(decision.selected, isNull);
    expect(decision.candidates.map((item) => item.animeId), [501, 502]);
  });

  test('low confidence candidates require manual selection', () {
    final decision = matcher.match(
      requestedAnime: '目标动画',
      requestedEpisode: 1,
      response: _response([
        _anime(
          animeId: 600,
          title: '完全不同作品',
          episodes: [_episode(60001, '第1话')],
        ),
      ]),
    );

    expect(decision.ambiguous, isTrue);
    expect(decision.selected, isNull);
    expect(decision.candidates.single.score, lessThan(80));
  });

  test('skips malformed anime and episode rows', () {
    final response = _response([
      {'animeId': 'bad', 'animeTitle': '坏数据', 'episodes': 'bad'},
      _anime(
        animeId: 700,
        title: '测试动画',
        episodes: [
          {'episodeId': 'bad', 'episodeTitle': '第1话'},
          _episode(70001, '第1话'),
        ],
      ),
    ]);

    final decision = matcher.match(
      requestedAnime: '测试动画',
      requestedEpisode: 1,
      response: response,
    );

    expect(decision.candidates, hasLength(1));
    expect(decision.selected?.episodeId, 70001);
  });
}
