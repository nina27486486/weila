import 'dart:async';

import 'package:flutter/foundation.dart';

import 'audio_session_playback_focus.dart';

/// 音频中断的原因（audio_session 事件映射）。
enum AudioInterruptionCause {
  /// 来电或系统级占用；结束后可以恢复播放。
  phoneCall,

  /// 其他应用要求独占音频；结束后不应自动恢复。
  pauseRequest,

  /// 其他应用请求闪避（短提示音等）。
  duck,
}

enum AudioFocusAction { none, pause, resume }

/// 中断决策纯逻辑：只恢复"因中断而暂停"的播放。
///
/// 规则（MVP 计划 §4）：
/// - 中断开始且正在播放 → 暂停（来电/独占/闪避都让路）；
/// - 中断结束且此前的暂停确由中断引起 → 恢复（pauseRequest 除外）；
/// - 拔耳机（becoming noisy）→ 暂停，且不标记为可恢复。
class AudioInterruptionPolicy {
  bool _pausedByInterruption = false;

  /// 上一次暂停是否由音频中断引起（诊断/测试用）。
  bool get pausedByInterruption => _pausedByInterruption;

  AudioFocusAction handleInterruptionBegin(
    AudioInterruptionCause cause, {
    required bool isPlaying,
  }) {
    if (!isPlaying) return AudioFocusAction.none;
    _pausedByInterruption = true;
    return AudioFocusAction.pause;
  }

  AudioFocusAction handleInterruptionEnd(
    AudioInterruptionCause cause, {
    required bool isPlaying,
  }) {
    if (!_pausedByInterruption) return AudioFocusAction.none;
    _pausedByInterruption = false;
    if (isPlaying) return AudioFocusAction.none;
    // 其他应用要求独占时，结束后让用户手动恢复。
    if (cause == AudioInterruptionCause.pauseRequest) {
      return AudioFocusAction.none;
    }
    return AudioFocusAction.resume;
  }

  AudioFocusAction handleBecomingNoisy({required bool isPlaying}) {
    if (!isPlaying) return AudioFocusAction.none;
    // 拔耳机只暂停，不进入"可恢复"状态。
    return AudioFocusAction.pause;
  }

  /// 用户手动暂停或换集时清除标记，避免旧中断误恢复。
  void reset() => _pausedByInterruption = false;
}

/// 播放音频焦点抽象：播放器在开始/停止播放时激活/释放，
/// 平台实现负责把系统中断事件翻译成暂停/恢复回调。
abstract interface class PlaybackAudioFocus {
  Future<void> activate();

  Future<void> deactivate();

  /// 播放器在播放状态变化时同步：中断决策需要知道当前是否在播。
  void notifyPlaybackStateChanged({required bool playing});

  void dispose();

  set onPausedByInterruption(VoidCallback? callback);
  set onResumeAfterInterruption(VoidCallback? callback);
  set onPausedByNoise(VoidCallback? callback);

  /// 按平台选择实现：移动端使用 audio_session，桌面为 Noop。
  factory PlaybackAudioFocus.platform() {
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)) {
      return audioFocusForMobilePlatforms();
    }
    return const NoopPlaybackAudioFocus();
  }
}

class NoopPlaybackAudioFocus implements PlaybackAudioFocus {
  const NoopPlaybackAudioFocus();

  @override
  Future<void> activate() async {}

  @override
  Future<void> deactivate() async {}

  @override
  void notifyPlaybackStateChanged({required bool playing}) {}

  @override
  void dispose() {}

  @override
  set onPausedByInterruption(VoidCallback? callback) {}

  @override
  set onResumeAfterInterruption(VoidCallback? callback) {}

  @override
  set onPausedByNoise(VoidCallback? callback) {}
}
