import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';

import 'audio_focus_controller.dart';

/// 移动端（Android/iOS）audio_session 实现。
///
/// 工厂函数放独立文件：audio_session 的导入只出现在这里与
/// audio_focus_controller.dart 的工厂转发处，桌面编译单元不受影响。
PlaybackAudioFocus audioFocusForMobilePlatforms() {
  return AudioSessionPlaybackFocus();
}

class AudioSessionPlaybackFocus implements PlaybackAudioFocus {
  AudioSessionPlaybackFocus({AudioInterruptionPolicy? policy})
      : _policy = policy ?? AudioInterruptionPolicy();

  final AudioInterruptionPolicy _policy;
  StreamSubscription<AudioInterruptionEvent>? _interruption;
  StreamSubscription<void>? _becomingNoisy;
  AudioSession? _session;
  bool _disposed = false;

  /// 测试钩子：当前策略状态。
  @visibleForTesting
  AudioInterruptionPolicy get policy => _policy;

  VoidCallback? _onPausedByInterruption;
  VoidCallback? _onResumeAfterInterruption;
  VoidCallback? _onPausedByNoise;
  bool _isPlaying = false;

  Future<AudioSession> _ensureSession() async {
    final existing = _session;
    if (existing != null) return existing;
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
    if (_disposed) {
      return session;
    }
    _session = session;
    _interruption ??= session.interruptionEventStream.listen(
      (event) => _handleInterruption(event),
      onError: (Object _) {},
    );
    _becomingNoisy ??= session.becomingNoisyEventStream.listen(
      (_) => _handleBecomingNoisy(),
      onError: (Object _) {},
    );
    return session;
  }

  void _handleInterruption(AudioInterruptionEvent event) {
    if (_disposed) return;
    final cause = switch (event.type) {
      AudioInterruptionType.duck => AudioInterruptionCause.duck,
      AudioInterruptionType.pause => AudioInterruptionCause.pauseRequest,
      AudioInterruptionType.unknown => AudioInterruptionCause.phoneCall,
    };
    final action = event.begin
        ? _policy.handleInterruptionBegin(cause, isPlaying: _isPlaying)
        : _policy.handleInterruptionEnd(cause, isPlaying: _isPlaying);
    _dispatch(action);
  }

  void _handleBecomingNoisy() {
    if (_disposed) return;
    final action = _policy.handleBecomingNoisy(isPlaying: _isPlaying);
    if (action == AudioFocusAction.pause) {
      _onPausedByNoise?.call();
    }
  }

  void _dispatch(AudioFocusAction action) {
    switch (action) {
      case AudioFocusAction.pause:
        _onPausedByInterruption?.call();
      case AudioFocusAction.resume:
        _onResumeAfterInterruption?.call();
      case AudioFocusAction.none:
        break;
    }
  }

  @override
  Future<void> activate() async {
    if (_disposed) return;
    try {
      final session = await _ensureSession();
      await session.setActive(true);
    } catch (_) {
      // 焦点获取失败不阻塞播放；系统会在真正冲突时发中断事件。
    }
  }

  @override
  Future<void> deactivate() async {
    if (_disposed) return;
    try {
      final session = _session;
      if (session != null) {
        await session.setActive(false);
      }
    } catch (_) {
      // 释放焦点失败无需处理。
    }
  }

  @override
  void notifyPlaybackStateChanged({required bool playing}) {
    _isPlaying = playing;
    if (!playing) {
      // 用户手动暂停/换集时清除可恢复标记，避免旧中断误恢复。
      _policy.reset();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_interruption?.cancel());
    unawaited(_becomingNoisy?.cancel());
    _interruption = null;
    _becomingNoisy = null;
  }

  @override
  set onPausedByInterruption(VoidCallback? callback) {
    _onPausedByInterruption = callback;
  }

  @override
  set onResumeAfterInterruption(VoidCallback? callback) {
    _onResumeAfterInterruption = callback;
  }

  @override
  set onPausedByNoise(VoidCallback? callback) {
    _onPausedByNoise = callback;
  }
}
