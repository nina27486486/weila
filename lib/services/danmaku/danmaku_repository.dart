import '../../models/danmaku_item.dart';
import 'dandanplay_api_client.dart';
import 'danmaku_diagnostics.dart';
import 'danmaku_load_result.dart';
import 'danmaku_matcher.dart';

abstract interface class DanmakuCacheStore {
  Object? read(String key);
  Future<void> write(String key, Object value);
  Future<void> remove(String key);
}

class SettingsDanmakuCacheStore implements DanmakuCacheStore {
  SettingsDanmakuCacheStore({
    required Object? Function(String key) read,
    required Future<void> Function(String key, Object value) write,
    required Future<void> Function(String key) remove,
  })  : _read = read,
        _write = write,
        _remove = remove;

  final Object? Function(String key) _read;
  final Future<void> Function(String key, Object value) _write;
  final Future<void> Function(String key) _remove;

  @override
  Object? read(String key) => _read(key);

  @override
  Future<void> remove(String key) => _remove(key);

  @override
  Future<void> write(String key, Object value) => _write(key, value);
}

class DanmakuRepository {
  DanmakuRepository({
    required DandanplayApi client,
    required DanmakuMatcher matcher,
    required DanmakuCacheStore cache,
    DateTime Function()? now,
  })  : _client = client,
        _matcher = matcher,
        _cache = cache,
        _now = now ?? DateTime.now;

  static const _searchCacheKey = 'danmaku_search_cache_v1';
  static const _matchCacheKey = 'danmaku_match_cache_v1';
  static const _commentCacheKey = 'danmaku_comment_cache_v1';
  static const _searchTtl = Duration(hours: 6);
  static const _matchTtl = Duration(days: 30);
  static const _commentTtl = Duration(hours: 2);
  static const _refreshDebounce = Duration(seconds: 10);

  final DandanplayApi _client;
  final DanmakuMatcher _matcher;
  final DanmakuCacheStore _cache;
  final DateTime Function() _now;
  final Map<String, DateTime> _lastRefreshAt = {};

  Future<DanmakuLoadResult> load({
    required String anime,
    required int episode,
    bool refresh = false,
  }) async {
    final cacheKey = _requestKey(anime, episode);
    final effectiveRefresh = _allowRefresh(cacheKey, refresh);
    try {
      if (!effectiveRefresh) {
        final matched = _readCandidate(_matchCacheKey, cacheKey);
        if (matched != null) {
          return _loadComments(matched, refresh: false);
        }
      }

      Map<String, dynamic>? cachedResponse;
      var responseChanged = false;
      if (!effectiveRefresh) {
        cachedResponse = _readMap(_searchCacheKey, cacheKey);
      }
      late Map<String, dynamic> response;
      if (cachedResponse == null) {
        response = await _client.searchEpisodes(anime, episode);
        responseChanged = true;
      } else {
        response = cachedResponse;
      }
      var decision = _matcher.match(
        requestedAnime: anime,
        requestedEpisode: episode,
        response: response,
      );
      final aliasSearchCompleted =
          response[_aliasSearchPlanVersionKey] == _aliasSearchPlanVersion;
      if (decision.candidates.isEmpty && !aliasSearchCompleted) {
        final fallbackQueries = _fallbackSearchQueries(anime);
        if (fallbackQueries.isNotEmpty) {
          for (final query in fallbackQueries) {
            final fallbackResponse =
                await _client.searchEpisodes(query, episode);
            response = Map<String, dynamic>.from(fallbackResponse);
            decision = _matcher.match(
              requestedAnime: anime,
              requestedEpisode: episode,
              response: response,
            );
            if (decision.candidates.isNotEmpty) break;
          }
          response[_aliasSearchPlanVersionKey] = _aliasSearchPlanVersion;
          response.remove(_legacyAliasSearchCompletedKey);
          responseChanged = true;
        }
      }
      if (responseChanged) {
        await _writeEntry(
          _searchCacheKey,
          cacheKey,
          response,
          ttl: _searchTtl,
          maximumEntries: 200,
        );
      }
      if (decision.candidates.isEmpty) {
        return DanmakuLoadResult(
          status: DanmakuLoadStatus.noMatch,
          diagnostics: const DanmakuLoadDiagnostics(
            errorStage: DanmakuErrorStage.match,
          ),
          safeMessage: '没有找到匹配的弹幕库',
        );
      }
      final selected = decision.selected;
      if (selected == null) {
        return DanmakuLoadResult(
          status: DanmakuLoadStatus.ambiguous,
          diagnostics: const DanmakuLoadDiagnostics(
            errorStage: DanmakuErrorStage.match,
          ),
          candidates: decision.candidates,
          safeMessage: '找到多个候选，请选择正确剧集',
        );
      }
      return _loadComments(selected, refresh: effectiveRefresh);
    } on DandanplayApiException catch (error) {
      return _errorResult(error, stage: DanmakuErrorStage.search);
    } catch (_) {
      return DanmakuLoadResult(
        status: DanmakuLoadStatus.networkFailed,
        diagnostics: const DanmakuLoadDiagnostics(
          errorStage: DanmakuErrorStage.search,
        ),
        safeMessage: '弹幕服务连接失败',
      );
    }
  }

  Future<DanmakuLoadResult> choose({
    required String anime,
    required int episode,
    required DanmakuMatchCandidate candidate,
  }) async {
    final cacheKey = _requestKey(anime, episode);
    await _writeEntry(
      _matchCacheKey,
      cacheKey,
      _candidateToMap(candidate),
      ttl: _matchTtl,
      maximumEntries: 200,
    );
    try {
      return await _loadComments(candidate, refresh: false);
    } on DandanplayApiException catch (error) {
      return _errorResult(
        error,
        stage: DanmakuErrorStage.comments,
        selected: candidate,
      );
    } catch (_) {
      return DanmakuLoadResult(
        status: DanmakuLoadStatus.networkFailed,
        selected: candidate,
        diagnostics: DanmakuLoadDiagnostics(
          episodeId: candidate.episodeId,
          errorStage: DanmakuErrorStage.comments,
        ),
        safeMessage: '弹幕服务连接失败',
      );
    }
  }

  Future<void> clear() async {
    await Future.wait([
      _cache.remove(_searchCacheKey),
      _cache.remove(_matchCacheKey),
      _cache.remove(_commentCacheKey),
    ]);
  }

  Future<DanmakuLoadResult> _loadComments(
    DanmakuMatchCandidate candidate, {
    required bool refresh,
  }) async {
    final key = '${candidate.episodeId}';
    var fromCache = false;
    Map<String, dynamic>? response;
    try {
      if (!refresh) {
        response = _readMap(_commentCacheKey, key);
        fromCache = response != null;
      }
      response ??= await _client.getComments(candidate.episodeId);
      if (!fromCache) {
        await _writeEntry(
          _commentCacheKey,
          key,
          response,
          ttl: _commentTtl,
          maximumEntries: 100,
        );
      }
    } on DandanplayApiException catch (error) {
      return _errorResult(
        error,
        stage: DanmakuErrorStage.comments,
        selected: candidate,
      );
    } catch (_) {
      return DanmakuLoadResult(
        status: DanmakuLoadStatus.networkFailed,
        selected: candidate,
        safeMessage: '弹幕服务连接失败',
        diagnostics: DanmakuLoadDiagnostics(
          episodeId: candidate.episodeId,
          errorStage: DanmakuErrorStage.comments,
        ),
      );
    }

    final comments = response['comments'];
    if (comments is! List) {
      return DanmakuLoadResult(
        status: DanmakuLoadStatus.malformedResponse,
        selected: candidate,
        safeMessage: '弹幕响应缺少评论列表',
        diagnostics: DanmakuLoadDiagnostics(
          episodeId: candidate.episodeId,
          errorStage: DanmakuErrorStage.comments,
        ),
      );
    }
    final items = <DanmakuItem>[];
    for (final value in comments) {
      if (value is! Map) continue;
      final item = DanmakuItem.tryParseDandanplay(
        value['p']?.toString() ?? '',
        value['m']?.toString() ?? '',
      );
      if (item != null) items.add(item);
    }
    items.sort((a, b) => a.time.compareTo(b.time));
    if (comments.isNotEmpty && items.isEmpty) {
      return DanmakuLoadResult(
        status: DanmakuLoadStatus.malformedResponse,
        selected: candidate,
        safeMessage: '弹幕数据无法解析',
        diagnostics: DanmakuLoadDiagnostics(
          episodeId: candidate.episodeId,
          commentCount: comments.length,
          errorStage: DanmakuErrorStage.parse,
        ),
      );
    }
    return DanmakuLoadResult(
      status: DanmakuLoadStatus.loaded,
      selected: candidate,
      items: items,
      fromCache: fromCache,
      diagnostics: DanmakuLoadDiagnostics(
        episodeId: candidate.episodeId,
        commentCount: comments.length,
        parsedCount: items.length,
      ),
    );
  }

  bool _allowRefresh(String key, bool requested) {
    if (!requested) return false;
    final now = _now();
    final last = _lastRefreshAt[key];
    if (last != null && now.difference(last) < _refreshDebounce) return false;
    _lastRefreshAt[key] = now;
    return true;
  }

  String _requestKey(String anime, int episode) {
    return '${anime.trim().toLowerCase()}|$episode';
  }

  static const _aliasSearchPlanVersion = 2;
  static const _aliasSearchPlanVersionKey = '_weilaAliasSearchPlanVersion';
  static const _legacyAliasSearchCompletedKey =
      '_weilaAliasSearchCompleted';

  List<String> _fallbackSearchQueries(String anime) {
    final title = anime.trim();
    final queries = <String>[];
    final seasonMatch = RegExp(r'^(.*?)([2-4])$').firstMatch(title);
    if (seasonMatch != null) {
      const seasonNumbers = <String, String>{
        '2': '二',
        '3': '三',
        '4': '四',
      };
      final baseTitle = seasonMatch.group(1)?.trim() ?? '';
      final seasonNumber = seasonNumbers[seasonMatch.group(2)];
      if (baseTitle.isNotEmpty && seasonNumber != null) {
        queries.add('$baseTitle 第$seasonNumber季');
      }
    }

    var canonicalDreamTitle = title.replaceFirst(
      RegExp(r'bang\s*dream', caseSensitive: false),
      'BanG Dream',
    );
    canonicalDreamTitle = canonicalDreamTitle.replaceFirst(
      RegExp(r'yume[\s_-]*mita', caseSensitive: false),
      'YUME∞MITA',
    );
    if (canonicalDreamTitle != title) {
      queries.add(canonicalDreamTitle);
      if (canonicalDreamTitle.contains('BanG Dream') &&
          canonicalDreamTitle.contains('YUME∞MITA')) {
        queries.add(
          canonicalDreamTitle.replaceFirst('YUME∞MITA', 'ゆめ∞みた'),
        );
      }
    }

    return queries.toSet().toList(growable: false);
  }

  Map<String, dynamic>? _readMap(String rootKey, String entryKey) {
    final value = _readEntry(rootKey, entryKey);
    return value is Map ? Map<String, dynamic>.from(value) : null;
  }

  DanmakuMatchCandidate? _readCandidate(String rootKey, String entryKey) {
    final value = _readEntry(rootKey, entryKey);
    if (value is! Map) return null;
    final animeId = value['animeId'];
    final episodeId = value['episodeId'];
    final score = value['score'];
    if (animeId is! int || episodeId is! int || score is! int) return null;
    return DanmakuMatchCandidate(
      animeId: animeId,
      animeTitle: value['animeTitle']?.toString() ?? '',
      typeDescription: value['typeDescription']?.toString() ?? '',
      episodeId: episodeId,
      episodeTitle: value['episodeTitle']?.toString() ?? '',
      score: score,
    );
  }

  Object? _readEntry(String rootKey, String entryKey) {
    final root = _cache.read(rootKey);
    if (root is! Map || root['version'] != 1 || root['entries'] is! Map) {
      return null;
    }
    final entry = (root['entries'] as Map)[entryKey];
    if (entry is! Map) return null;
    final expiresAt = DateTime.tryParse(entry['expiresAt']?.toString() ?? '');
    if (expiresAt == null || !_now().toUtc().isBefore(expiresAt.toUtc())) {
      return null;
    }
    return entry['value'];
  }

  Future<void> _writeEntry(
    String rootKey,
    String entryKey,
    Object value, {
    required Duration ttl,
    required int maximumEntries,
  }) async {
    final now = _now().toUtc();
    final existing = _cache.read(rootKey);
    final entries = <String, dynamic>{};
    if (existing is Map &&
        existing['version'] == 1 &&
        existing['entries'] is Map) {
      for (final item in (existing['entries'] as Map).entries) {
        if (item.key is! String || item.value is! Map) continue;
        final expiresAt = DateTime.tryParse(
            (item.value as Map)['expiresAt']?.toString() ?? '');
        if (expiresAt != null && now.isBefore(expiresAt.toUtc())) {
          entries[item.key as String] = item.value;
        }
      }
    }
    entries[entryKey] = {
      'value': value,
      'expiresAt': now.add(ttl).toIso8601String(),
      'lastAccessAt': now.toIso8601String(),
    };
    final sorted = entries.entries.toList()
      ..sort((a, b) {
        final aTime = DateTime.tryParse(
              (a.value as Map)['lastAccessAt']?.toString() ?? '',
            ) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = DateTime.tryParse(
              (b.value as Map)['lastAccessAt']?.toString() ?? '',
            ) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });
    await _cache.write(rootKey, {
      'version': 1,
      'entries': {
        for (final item in sorted.take(maximumEntries)) item.key: item.value,
      },
    });
  }

  Map<String, dynamic> _candidateToMap(DanmakuMatchCandidate candidate) => {
        'animeId': candidate.animeId,
        'animeTitle': candidate.animeTitle,
        'typeDescription': candidate.typeDescription,
        'episodeId': candidate.episodeId,
        'episodeTitle': candidate.episodeTitle,
        'score': candidate.score,
      };

  DanmakuLoadResult _errorResult(
    DandanplayApiException error, {
    required DanmakuErrorStage stage,
    DanmakuMatchCandidate? selected,
  }) {
    final status = switch (error.kind) {
      DandanplayApiErrorKind.notConfigured ||
      DandanplayApiErrorKind.invalidTimestamp ||
      DandanplayApiErrorKind.invalidAppId ||
      DandanplayApiErrorKind.invalidSignature =>
        DanmakuLoadStatus.authFailed,
      DandanplayApiErrorKind.quotaExceeded => DanmakuLoadStatus.quotaExceeded,
      DandanplayApiErrorKind.malformedResponse =>
        DanmakuLoadStatus.malformedResponse,
      _ => DanmakuLoadStatus.networkFailed,
    };
    return DanmakuLoadResult(
      status: status,
      selected: selected,
      safeMessage: error.safeMessage,
      diagnostics: DanmakuLoadDiagnostics(
        episodeId: selected?.episodeId,
        errorStage: stage,
      ),
    );
  }
}
