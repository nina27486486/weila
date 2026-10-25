import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weila/platform/audio_focus_controller.dart';

void main() {
  group('AudioInterruptionPolicy', () {
    test('中断开始时暂停正在播放的音频', () {
      final policy = AudioInterruptionPolicy();
      expect(
        policy.handleInterruptionBegin(
          AudioInterruptionCause.phoneCall,
          isPlaying: true,
        ),
        AudioFocusAction.pause,
      );
      expect(policy.pausedByInterruption, isTrue);
    });

    test('未播放时中断开始不动作', () {
      final policy = AudioInterruptionPolicy();
      expect(
        policy.handleInterruptionBegin(
          AudioInterruptionCause.phoneCall,
          isPlaying: false,
        ),
        AudioFocusAction.none,
      );
      expect(policy.pausedByInterruption, isFalse);
    });

    test('来电结束后恢复此前因中断暂停的播放', () {
      final policy = AudioInterruptionPolicy();
      policy.handleInterruptionBegin(
        AudioInterruptionCause.phoneCall,
        isPlaying: true,
      );
      expect(
        policy.handleInterruptionEnd(
          AudioInterruptionCause.phoneCall,
          isPlaying: false,
        ),
        AudioFocusAction.resume,
      );
      expect(policy.pausedByInterruption, isFalse);
    });

    test('其他应用独占（pauseRequest）结束后不自动恢复', () {
      final policy = AudioInterruptionPolicy();
      policy.handleInterruptionBegin(
        AudioInterruptionCause.pauseRequest,
        isPlaying: true,
      );
      expect(
        policy.handleInterruptionEnd(
          AudioInterruptionCause.pauseRequest,
          isPlaying: false,
        ),
        AudioFocusAction.none,
      );
    });

    test('用户手动暂停过的播放不因中断结束而恢复', () {
      final policy = AudioInterruptionPolicy();
      policy.handleInterruptionBegin(
        AudioInterruptionCause.phoneCall,
        isPlaying: true,
      );
      // 用户在通话期间手动暂停（播放态变化触发 reset）。
      policy.reset();
      expect(
        policy.handleInterruptionEnd(
          AudioInterruptionCause.phoneCall,
          isPlaying: false,
        ),
        AudioFocusAction.none,
      );
    });

    test('中断结束时已在播放则不重复恢复', () {
      final policy = AudioInterruptionPolicy();
      policy.handleInterruptionBegin(
        AudioInterruptionCause.phoneCall,
        isPlaying: true,
      );
      expect(
        policy.handleInterruptionEnd(
          AudioInterruptionCause.phoneCall,
          isPlaying: true,
        ),
        AudioFocusAction.none,
      );
    });

    test('没有中断历史时结束事件不动作', () {
      final policy = AudioInterruptionPolicy();
      expect(
        policy.handleInterruptionEnd(
          AudioInterruptionCause.phoneCall,
          isPlaying: false,
        ),
        AudioFocusAction.none,
      );
    });

    test('拔耳机暂停且不进入可恢复状态', () {
      final policy = AudioInterruptionPolicy();
      expect(
        policy.handleBecomingNoisy(isPlaying: true),
        AudioFocusAction.pause,
      );
      expect(policy.pausedByInterruption, isFalse);
      expect(
        policy.handleBecomingNoisy(isPlaying: false),
        AudioFocusAction.none,
      );
    });
  });

  group('NoopPlaybackAudioFocus', () {
    test('所有操作均为安全的空实现', () async {
      const focus = NoopPlaybackAudioFocus();
      focus.onPausedByInterruption = null;
      focus.onResumeAfterInterruption = null;
      focus.onPausedByNoise = null;
      focus.notifyPlaybackStateChanged(playing: true);
      await focus.activate();
      await focus.deactivate();
      focus.dispose();
    });
  });

  group('PlaybackAudioFocus.platform 工厂', () {
    test('debug 注入的桌面平台返回 Noop 实现', () {
      // 测试环境无法可靠切换 defaultTargetPlatform 的构造行为；
      // 通过 debugDefaultTargetPlatformOverride 覆盖为 windows 验证工厂。
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      expect(PlaybackAudioFocus.platform(), isA<NoopPlaybackAudioFocus>());
    });

    test('Android 平台返回移动实现', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      expect(
        PlaybackAudioFocus.platform(),
        isA<PlaybackAudioFocus>(),
      );
      expect(
        PlaybackAudioFocus.platform(),
        isNot(isA<NoopPlaybackAudioFocus>()),
      );
    });
  });
}
