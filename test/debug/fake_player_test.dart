import 'package:flutter_test/flutter_test.dart';
import 'package:weila/debug/fake_player.dart';

void main() {
  test('advances on a fixed local timeline and stops at sixty seconds', () {
    final ticker = _ManualTicker();
    final player = FakePlayer(ticker: ticker);

    expect(player.position, Duration.zero);
    expect(player.duration, const Duration(seconds: 60));
    expect(player.playing, isFalse);

    player.play();
    ticker.elapse(const Duration(milliseconds: 100));
    expect(player.position, const Duration(milliseconds: 100));
    expect(player.playing, isTrue);

    ticker.elapse(const Duration(seconds: 70));
    expect(player.position, const Duration(seconds: 60));
    expect(player.playing, isFalse);
    expect(ticker.running, isFalse);
  });

  test('pause, seek, and reset are deterministic', () {
    final ticker = _ManualTicker();
    final player = FakePlayer(ticker: ticker)..play();

    ticker.elapse(const Duration(seconds: 1));
    player.pause();
    ticker.elapse(const Duration(seconds: 1));
    expect(player.position, const Duration(seconds: 1));

    player.seek(const Duration(seconds: 12, milliseconds: 345));
    expect(player.position, const Duration(seconds: 12, milliseconds: 345));
    player.seek(const Duration(seconds: 99));
    expect(player.position, const Duration(seconds: 60));

    player.reset();
    expect(player.position, Duration.zero);
    expect(player.playing, isFalse);
    expect(ticker.running, isFalse);
  });
}

class _ManualTicker implements LocalTimelineTicker {
  void Function(Duration delta)? _onTick;

  bool get running => _onTick != null;

  @override
  void start(void Function(Duration delta) onTick) {
    _onTick = onTick;
  }

  void elapse(Duration delta) => _onTick?.call(delta);

  @override
  void stop() => _onTick = null;

  @override
  void dispose() => stop();
}
