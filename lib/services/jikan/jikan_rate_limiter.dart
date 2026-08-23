import 'dart:async';

/// Jikan 限流契约：acquire 返回即获得一个请求名额。
abstract interface class CatalogRequestLimiter {
  Future<void> acquire();
}

typedef JikanClock = DateTime Function();
typedef JikanDelay = Future<void> Function(Duration duration);

/// Jikan（MyAnimeList）官方限制：60 req/min、3 req/sec。
/// 滑动窗口实现，跨调用方共享 [sharedJikanRateLimiter] 一个名额池，
/// 避免目录通道与首页/搜索通道各自打满配额。
class JikanRequestLimiter implements CatalogRequestLimiter {
  JikanRequestLimiter({JikanClock? now, JikanDelay? delay})
      : _now = now ?? DateTime.now,
        _delay = delay ?? Future<void>.delayed;

  final JikanClock _now;
  final JikanDelay _delay;
  final List<DateTime> _admitted = [];
  Future<void> _tail = Future<void>.value();

  @override
  Future<void> acquire() {
    final result = _tail.then((_) => _waitForSlot());
    _tail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return result;
  }

  Future<void> _waitForSlot() async {
    while (true) {
      final now = _now().toUtc();
      _admitted.removeWhere(
        (instant) =>
            !instant.isAfter(now.subtract(const Duration(minutes: 1))),
      );
      final inSecond = _admitted
          .where(
            (instant) =>
                instant.isAfter(now.subtract(const Duration(seconds: 1))),
          )
          .toList(growable: false);
      Duration wait = Duration.zero;
      if (inSecond.length >= 3) {
        wait = inSecond.first.add(const Duration(seconds: 1)).difference(now);
      }
      if (_admitted.length >= 60) {
        final minuteWait =
            _admitted.first.add(const Duration(minutes: 1)).difference(now);
        if (minuteWait > wait) wait = minuteWait;
      }
      if (wait <= Duration.zero) {
        _admitted.add(now);
        return;
      }
      await _delay(wait);
    }
  }
}

/// 全应用共享的 Jikan 限流器实例。
final CatalogRequestLimiter sharedJikanRateLimiter = JikanRequestLimiter();
