import 'package:flutter_test/flutter_test.dart';
import 'package:weila/services/danmaku/dandanplay_api_client.dart';
import 'package:weila/services/danmaku/danmaku_diagnostics.dart';
import 'package:weila/services/danmaku/danmaku_load_result.dart';
import 'package:weila/services/danmaku/danmaku_matcher.dart';
import 'package:weila/services/danmaku/danmaku_repository.dart';

Map<String, dynamic> _searchResponse({
  String title = '测试动画',
  int animeId = 1,
  int episodeId = 10001,
}) {
  return {
    'success': true,
    'animes': [
      {
        'animeId': animeId,
        'animeTitle': title,
        'typeDescription': 'TV动画',
        'episodes': [
          {'episodeId': episodeId, 'episodeTitle': '第1话'},
        ],
      },
    ],
  };
}

Map<String, dynamic> _commentsResponse() => {
      'count': 2,
      'comments': [
        {'p': '2,1,16777215,9', 'm': '第二条'},
        {'p': '1,5,16711680,8', 'm': '第一条'},
      ],
    };

Map<String, dynamic> _mixedCommentsResponse() => {
      'count': 3,
      'comments': [
        {'p': '2,1,16777215,9', 'm': 'valid two'},
        {'p': 'invalid', 'm': 'invalid'},
        {'p': '1,5,16711680,8', 'm': 'valid one'},
      ],
    };

void main() {
  test('loads unique search result and sorted real comments', () async {
    final api = _FakeDandanplayApi(
      searchResponse: _searchResponse(),
      commentsResponse: _commentsResponse(),
    );
    final repository = DanmakuRepository(
      client: api,
      matcher: const DanmakuMatcher(),
      cache: _MemoryDanmakuCache(),
    );

    final result = await repository.load(anime: '测试动画', episode: 1);

    expect(result.status, DanmakuLoadStatus.loaded);
    expect(result.selected?.episodeId, 10001);
    expect(result.items.map((item) => item.text), ['第一条', '第二条']);
    expect(api.searchCalls, 1);
    expect(api.commentCalls, 1);
  });

  test('reports raw and parsed comment counts for a successful load', () async {
    final repository = DanmakuRepository(
      client: _FakeDandanplayApi(
        searchResponse: _searchResponse(title: 'Test Anime'),
        commentsResponse: _mixedCommentsResponse(),
      ),
      matcher: const DanmakuMatcher(),
      cache: _MemoryDanmakuCache(),
    );

    final result = await repository.load(anime: 'Test Anime', episode: 1);

    expect(result.diagnostics.episodeId, 10001);
    expect(result.diagnostics.commentCount, 3);
    expect(result.diagnostics.parsedCount, 2);
    expect(result.diagnostics.errorStage, DanmakuErrorStage.none);
  });

  test('retries a trailing numeric sequel with a Chinese season title',
      () async {
    final api = _FakeDandanplayApi(
      searchResponses: {
        '幼女战记2': const {'success': true, 'animes': <Object>[]},
        '幼女战记 第二季': _searchResponse(
          title: '幼女战记 第二季',
          animeId: 210,
          episodeId: 21001,
        ),
      },
      commentsResponse: _commentsResponse(),
    );
    final repository = DanmakuRepository(
      client: api,
      matcher: const DanmakuMatcher(),
      cache: _MemoryDanmakuCache(),
    );

    final result = await repository.load(anime: '幼女战记2', episode: 1);

    expect(result.status, DanmakuLoadStatus.loaded);
    expect(result.selected?.episodeId, 21001);
    expect(api.searchedAnimes, ['幼女战记2', '幼女战记 第二季']);
  });

  test('retries a CMS YUME-MITA alias with the searchable Japanese title',
      () async {
    final api = _FakeDandanplayApi(
      searchResponses: {
        'banGDream! YUME-MITA': const {
          'success': true,
          'animes': <Object>[],
        },
        'BanG Dream! YUME∞MITA': const {
          'success': true,
          'animes': <Object>[],
        },
        'BanG Dream! ゆめ∞みた': _searchResponse(
          title: 'BanG Dream! YUME∞MITA',
          animeId: 220,
          episodeId: 22001,
        ),
      },
      commentsResponse: _commentsResponse(),
    );
    final repository = DanmakuRepository(
      client: api,
      matcher: const DanmakuMatcher(),
      cache: _MemoryDanmakuCache(),
    );

    final result =
        await repository.load(anime: 'banGDream! YUME-MITA', episode: 1);

    expect(result.status, DanmakuLoadStatus.loaded);
    expect(result.selected?.episodeId, 22001);
    expect(
      api.searchedAnimes,
      [
        'banGDream! YUME-MITA',
        'BanG Dream! YUME∞MITA',
        'BanG Dream! ゆめ∞みた',
      ],
    );
  });

  test('retries an old unsuccessful alias cache after the planner changes',
      () async {
    final now = DateTime.utc(2026, 7, 30, 12);
    final cache = _MemoryDanmakuCache();
    cache.values['danmaku_search_cache_v1'] = {
      'version': 1,
      'entries': {
        'bangdream! yume-mita|1': {
          'value': {
            'success': true,
            'animes': <Object>[],
            '_weilaAliasSearchCompleted': true,
          },
          'expiresAt': now.add(const Duration(hours: 1)).toIso8601String(),
          'lastAccessAt': now.toIso8601String(),
        },
      },
    };
    final api = _FakeDandanplayApi(
      searchResponses: {
        'BanG Dream! YUME∞MITA': const {
          'success': true,
          'animes': <Object>[],
        },
        'BanG Dream! ゆめ∞みた': _searchResponse(
          title: 'BanG Dream! YUME∞MITA',
          animeId: 220,
          episodeId: 22001,
        ),
      },
      commentsResponse: _commentsResponse(),
    );
    final repository = DanmakuRepository(
      client: api,
      matcher: const DanmakuMatcher(),
      cache: cache,
      now: () => now,
    );

    final result =
        await repository.load(anime: 'banGDream! YUME-MITA', episode: 1);

    expect(result.status, DanmakuLoadStatus.loaded);
    expect(result.selected?.episodeId, 22001);
    expect(
      api.searchedAnimes,
      ['BanG Dream! YUME∞MITA', 'BanG Dream! ゆめ∞みた'],
    );
  });

  test('caches an unsuccessful alias search to avoid repeated API calls',
      () async {
    final api = _FakeDandanplayApi(
      searchResponses: const {
        '幼女战记2': {'success': true, 'animes': <Object>[]},
        '幼女战记 第二季': {'success': true, 'animes': <Object>[]},
      },
    );
    final repository = DanmakuRepository(
      client: api,
      matcher: const DanmakuMatcher(),
      cache: _MemoryDanmakuCache(),
    );

    final first = await repository.load(anime: '幼女战记2', episode: 1);
    final cached = await repository.load(anime: '幼女战记2', episode: 1);

    expect(first.status, DanmakuLoadStatus.noMatch);
    expect(cached.status, DanmakuLoadStatus.noMatch);
    expect(api.searchedAnimes, ['幼女战记2', '幼女战记 第二季']);
  });

  test('reports search, match, comments, and parse failure stages', () async {
    Future<DanmakuLoadResult> loadWith(_FakeDandanplayApi api) {
      return DanmakuRepository(
        client: api,
        matcher: const DanmakuMatcher(),
        cache: _MemoryDanmakuCache(),
      ).load(anime: 'Test Anime', episode: 1);
    }

    final searchFailed = await loadWith(
      _FakeDandanplayApi(
        searchErrorKind: DandanplayApiErrorKind.timeout,
      ),
    );
    final noMatch = await loadWith(
      _FakeDandanplayApi(
        searchResponse: const {'success': true, 'animes': <Object>[]},
      ),
    );
    final commentsFailed = await loadWith(
      _FakeDandanplayApi(
        searchResponse: _searchResponse(title: 'Test Anime'),
        commentsErrorKind: DandanplayApiErrorKind.timeout,
      ),
    );
    final parseFailed = await loadWith(
      _FakeDandanplayApi(
        searchResponse: _searchResponse(title: 'Test Anime'),
        commentsResponse: {
          'count': 1,
          'comments': [
            {'p': 'invalid', 'm': 'cannot parse'},
          ],
        },
      ),
    );

    expect(searchFailed.diagnostics.errorStage, DanmakuErrorStage.search);
    expect(noMatch.diagnostics.errorStage, DanmakuErrorStage.match);
    expect(commentsFailed.diagnostics.errorStage, DanmakuErrorStage.comments);
    expect(commentsFailed.diagnostics.episodeId, 10001);
    expect(parseFailed.status, DanmakuLoadStatus.malformedResponse);
    expect(parseFailed.diagnostics.errorStage, DanmakuErrorStage.parse);
    expect(parseFailed.diagnostics.commentCount, 1);
    expect(parseFailed.diagnostics.parsedCount, 0);
  });

  test('ambiguous results do not request comments until user chooses',
      () async {
    final response = _searchResponse();
    (response['animes'] as List).add(
      (_searchResponse(animeId: 2, episodeId: 20001)['animes'] as List).single,
    );
    final api = _FakeDandanplayApi(
      searchResponse: response,
      commentsResponse: _commentsResponse(),
    );
    final repository = DanmakuRepository(
      client: api,
      matcher: const DanmakuMatcher(),
      cache: _MemoryDanmakuCache(),
    );

    final ambiguous = await repository.load(anime: '测试动画', episode: 1);
    final chosen = await repository.choose(
      anime: '测试动画',
      episode: 1,
      candidate: ambiguous.candidates.last,
    );

    expect(ambiguous.status, DanmakuLoadStatus.ambiguous);
    expect(api.commentCalls, 1);
    expect(chosen.status, DanmakuLoadStatus.loaded);
    expect(chosen.selected?.episodeId, 20001);
  });

  test('search cache lasts six hours and comments cache lasts two hours',
      () async {
    var now = DateTime.utc(2026, 7, 11, 12);
    final api = _FakeDandanplayApi(
      searchResponse: _searchResponse(),
      commentsResponse: _commentsResponse(),
    );
    final repository = DanmakuRepository(
      client: api,
      matcher: const DanmakuMatcher(),
      cache: _MemoryDanmakuCache(),
      now: () => now,
    );

    await repository.load(anime: '测试动画', episode: 1);
    now = now.add(const Duration(hours: 1, minutes: 59));
    final cached = await repository.load(anime: '测试动画', episode: 1);
    expect(cached.fromCache, isTrue);
    expect(api.searchCalls, 1);
    expect(api.commentCalls, 1);

    now = now.add(const Duration(minutes: 2));
    await repository.load(anime: '测试动画', episode: 1);
    expect(api.searchCalls, 1);
    expect(api.commentCalls, 2);

    now = now.add(const Duration(hours: 4, minutes: 1));
    await repository.load(anime: '测试动画', episode: 1);
    expect(api.searchCalls, 2);
  });

  test('confirmed episode association bypasses search for thirty days',
      () async {
    var now = DateTime.utc(2026, 7, 11, 12);
    final api = _FakeDandanplayApi(
      searchResponse: _searchResponse(),
      commentsResponse: _commentsResponse(),
    );
    final cache = _MemoryDanmakuCache();
    final repository = DanmakuRepository(
      client: api,
      matcher: const DanmakuMatcher(),
      cache: cache,
      now: () => now,
    );
    final first = await repository.load(anime: '测试动画', episode: 1);
    await repository.choose(
      anime: '测试动画',
      episode: 1,
      candidate: first.selected!,
    );
    api.searchCalls = 0;
    now = now.add(const Duration(days: 29));

    await repository.load(anime: '测试动画', episode: 1);

    expect(api.searchCalls, 0);
  });

  test('maps API errors to explicit load states', () async {
    Future<DanmakuLoadStatus> statusFor(DandanplayApiErrorKind kind) async {
      final repository = DanmakuRepository(
        client: _FakeDandanplayApi(errorKind: kind),
        matcher: const DanmakuMatcher(),
        cache: _MemoryDanmakuCache(),
      );
      return (await repository.load(anime: '测试动画', episode: 1)).status;
    }

    expect(await statusFor(DandanplayApiErrorKind.invalidSignature),
        DanmakuLoadStatus.authFailed);
    expect(await statusFor(DandanplayApiErrorKind.quotaExceeded),
        DanmakuLoadStatus.quotaExceeded);
    expect(await statusFor(DandanplayApiErrorKind.timeout),
        DanmakuLoadStatus.networkFailed);
    expect(await statusFor(DandanplayApiErrorKind.malformedResponse),
        DanmakuLoadStatus.malformedResponse);
  });
}

class _FakeDandanplayApi implements DandanplayApi {
  _FakeDandanplayApi({
    this.searchResponse,
    this.searchResponses,
    this.commentsResponse,
    this.errorKind,
    this.searchErrorKind,
    this.commentsErrorKind,
  });

  final Map<String, dynamic>? searchResponse;
  final Map<String, Map<String, dynamic>>? searchResponses;
  final Map<String, dynamic>? commentsResponse;
  final DandanplayApiErrorKind? errorKind;
  final DandanplayApiErrorKind? searchErrorKind;
  final DandanplayApiErrorKind? commentsErrorKind;
  int searchCalls = 0;
  int commentCalls = 0;
  final List<String> searchedAnimes = [];

  @override
  Future<Map<String, dynamic>> getComments(int episodeId) async {
    commentCalls += 1;
    _throwIfNeeded(commentsErrorKind ?? errorKind);
    return commentsResponse ?? _commentsResponse();
  }

  @override
  Future<Map<String, dynamic>> searchEpisodes(String anime, int episode) async {
    searchCalls += 1;
    searchedAnimes.add(anime);
    _throwIfNeeded(searchErrorKind ?? errorKind);
    return searchResponses?[anime] ?? searchResponse ?? _searchResponse();
  }

  void _throwIfNeeded(DandanplayApiErrorKind? kind) {
    if (kind != null) throw DandanplayApiException(kind, 'safe error');
  }
}

class _MemoryDanmakuCache implements DanmakuCacheStore {
  final Map<String, Object> values = {};

  @override
  Object? read(String key) => values[key];

  @override
  Future<void> remove(String key) async => values.remove(key);

  @override
  Future<void> write(String key, Object value) async => values[key] = value;
}
