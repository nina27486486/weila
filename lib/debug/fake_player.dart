import 'dart:async';

import 'package:flutter/foundation.dart';

abstract interface class LocalTimelineTicker {
  void start(void Function(Duration delta) onTick);
  void stop();
  void dispose();
}

class PeriodicLocalTimelineTicker implements LocalTimelineTicker {
  PeriodicLocalTimelineTicker({
    this.interval = const Duration(milliseconds: 100),
  });

  final Duration interval;
  Timer? _timer;

  @override
  void start(void Function(Duration delta) onTick) {
    stop();
    _timer = Timer.periodic(interval, (_) => onTick(interval));
  }

  @override
  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() => stop();
}

class FakePlayer extends ChangeNotifier {
  FakePlayer({
    LocalTimelineTicker? ticker,
    this.duration = const Duration(seconds: 60),
  }) : _ticker = ticker ?? PeriodicLocalTimelineTicker();

  final LocalTimelineTicker _ticker;
  final Duration duration;

  Duration _position = Duration.zero;
  bool _playing = false;

  Duration get position => _position;
  bool get playing => _playing;

  void play() {
    if (_playing || _position >= duration) return;
    _playing = true;
    _ticker.start(_advance);
    notifyListeners();
  }

  void pause() {
    if (!_playing) return;
    _playing = false;
    _ticker.stop();
    notifyListeners();
  }

  void seek(Duration target) {
    final milliseconds =
        target.inMilliseconds.clamp(0, duration.inMilliseconds);
    _position = Duration(milliseconds: milliseconds);
    if (_position >= duration && _playing) {
      _playing = false;
      _ticker.stop();
    }
    notifyListeners();
  }

  void reset() {
    _ticker.stop();
    _playing = false;
    _position = Duration.zero;
    notifyListeners();
  }

  void _advance(Duration delta) {
    if (!_playing) return;
    final next = _position + delta;
    if (next >= duration) {
      _position = duration;
      _playing = false;
      _ticker.stop();
    } else {
      _position = next;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }
}
