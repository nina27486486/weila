import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../../../theme/vira_colors.dart';

class PlayerControlBar extends StatelessWidget {
  const PlayerControlBar({
    super.key,
    required this.position,
    required this.duration,
    required this.playing,
    required this.volume,
    required this.playbackSpeed,
    required this.fullscreen,
    required this.canPlayNext,
    required this.onSeek,
    required this.onRewind,
    required this.onTogglePlay,
    required this.onForward,
    required this.onPlayNext,
    required this.onVolumeChanged,
    required this.onSpeedChanged,
    required this.onToggleFullscreen,
  });

  final Duration position;
  final Duration duration;
  final bool playing;
  final double volume;
  final double playbackSpeed;
  final bool fullscreen;
  final bool canPlayNext;
  final ValueChanged<Duration> onSeek;
  final VoidCallback onRewind;
  final VoidCallback onTogglePlay;
  final VoidCallback onForward;
  final VoidCallback onPlayNext;
  final ValueChanged<double> onVolumeChanged;
  final ValueChanged<double> onSpeedChanged;
  final VoidCallback onToggleFullscreen;

  static const _speeds = <double>[0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

  double get _progress {
    if (duration.inMilliseconds <= 0) return 0;
    return (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        return Container(
          padding: EdgeInsets.fromLTRB(
            compact ? 14 : 22,
            compact ? 36 : 48,
            compact ? 14 : 22,
            compact ? 12 : 18,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                Colors.black.withValues(alpha: 0.94),
                Colors.black.withValues(alpha: 0.62),
                Colors.transparent,
              ],
              stops: const [0, 0.7, 1],
            ),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ProgressRow(
                  position: position,
                  duration: duration,
                  progress: _progress,
                  active: playing,
                  onChanged: (value) {
                    final milliseconds =
                        (duration.inMilliseconds * value).round();
                    onSeek(Duration(milliseconds: milliseconds));
                  },
                ),
                SizedBox(height: compact ? 4 : 7),
                _TransportRow(
                  playing: playing,
                  volume: volume.clamp(0, 100),
                  playbackSpeed: playbackSpeed,
                  fullscreen: fullscreen,
                  canPlayNext: canPlayNext,
                  compact: compact,
                  speeds: _speeds,
                  onRewind: onRewind,
                  onTogglePlay: onTogglePlay,
                  onForward: onForward,
                  onPlayNext: onPlayNext,
                  onVolumeChanged: onVolumeChanged,
                  onSpeedChanged: onSpeedChanged,
                  onToggleFullscreen: onToggleFullscreen,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({
    required this.position,
    required this.duration,
    required this.progress,
    required this.active,
    required this.onChanged,
  });

  final Duration position;
  final Duration duration;
  final double progress;
  final bool active;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _TimeLabel(
          value: _formatDuration(position),
          alignment: Alignment.centerLeft,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: AnimatedContainer(
            key: const ValueKey('player-progress-glow'),
            duration: const Duration(milliseconds: 160),
            decoration: BoxDecoration(
              boxShadow: active && progress > 0
                  ? [
                      BoxShadow(
                        color: AppTheme.primaryBlue.withValues(alpha: 0.42),
                        blurRadius: 9,
                        spreadRadius: -2,
                      ),
                    ]
                  : const [],
            ),
            child: Semantics(
              label: '播放进度',
              value: '${(progress * 100).round()}%',
              child: SliderTheme(
                data: SliderThemeData(
                  activeTrackColor: AppTheme.primaryBlue,
                  inactiveTrackColor: Colors.white.withValues(alpha: 0.2),
                  secondaryActiveTrackColor:
                      Colors.white.withValues(alpha: 0.34),
                  thumbColor: Colors.white,
                  overlayColor: AppTheme.primaryBlue.withValues(alpha: 0.18),
                  trackHeight: 3,
                  thumbShape:
                      const RoundSliderThumbShape(enabledThumbRadius: 5.5),
                  overlayShape:
                      const RoundSliderOverlayShape(overlayRadius: 13),
                ),
                child: Slider(
                  key: const ValueKey('player-progress-slider'),
                  value: progress,
                  onChanged: onChanged,
                  semanticFormatterCallback: (value) =>
                      '播放进度 ${(value * 100).round()}%',
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        _TimeLabel(
          value: _formatDuration(duration),
          alignment: Alignment.centerRight,
        ),
      ],
    );
  }
}

class _TimeLabel extends StatelessWidget {
  const _TimeLabel({
    required this.value,
    required this.alignment,
  });

  final String value;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      child: Align(
        alignment: alignment,
        child: Text(
          value,
          maxLines: 1,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.72),
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}

class _TransportRow extends StatelessWidget {
  const _TransportRow({
    required this.playing,
    required this.volume,
    required this.playbackSpeed,
    required this.fullscreen,
    required this.canPlayNext,
    required this.compact,
    required this.speeds,
    required this.onRewind,
    required this.onTogglePlay,
    required this.onForward,
    required this.onPlayNext,
    required this.onVolumeChanged,
    required this.onSpeedChanged,
    required this.onToggleFullscreen,
  });

  final bool playing;
  final double volume;
  final double playbackSpeed;
  final bool fullscreen;
  final bool canPlayNext;
  final bool compact;
  final List<double> speeds;
  final VoidCallback onRewind;
  final VoidCallback onTogglePlay;
  final VoidCallback onForward;
  final VoidCallback onPlayNext;
  final ValueChanged<double> onVolumeChanged;
  final ValueChanged<double> onSpeedChanged;
  final VoidCallback onToggleFullscreen;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ControlIconButton(
          icon: Icons.replay_5_rounded,
          tooltip: '后退 5 秒',
          onPressed: onRewind,
        ),
        const SizedBox(width: 7),
        _PrimaryPlayButton(
          playing: playing,
          onPressed: onTogglePlay,
        ),
        const SizedBox(width: 7),
        _ControlIconButton(
          icon: Icons.forward_5_rounded,
          tooltip: '前进 5 秒',
          onPressed: onForward,
        ),
        if (canPlayNext) ...[
          SizedBox(width: compact ? 4 : 10),
          if (compact)
            _ControlIconButton(
              icon: Icons.skip_next_rounded,
              tooltip: '播放下一集',
              onPressed: onPlayNext,
            )
          else
            _NextEpisodeButton(onPressed: onPlayNext),
        ],
        const Spacer(),
        Icon(
          volume <= 0
              ? Icons.volume_off_rounded
              : volume < 50
                  ? Icons.volume_down_rounded
                  : Icons.volume_up_rounded,
          color: Colors.white.withValues(alpha: 0.72),
          size: 19,
        ),
        SizedBox(width: compact ? 2 : 5),
        SizedBox(
          width: compact ? 72 : 112,
          child: Semantics(
            label: '音量',
            value: '${volume.round()}%',
            child: SliderTheme(
              data: SliderThemeData(
                activeTrackColor: Colors.white.withValues(alpha: 0.82),
                inactiveTrackColor: Colors.white.withValues(alpha: 0.18),
                thumbColor: AppTheme.primaryBlue,
                overlayColor: AppTheme.primaryBlue.withValues(alpha: 0.14),
                trackHeight: 2.5,
                thumbShape:
                    const RoundSliderThumbShape(enabledThumbRadius: 4.5),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 11),
              ),
              child: Slider(
                key: const ValueKey('player-volume-slider'),
                value: volume,
                min: 0,
                max: 100,
                onChanged: onVolumeChanged,
                semanticFormatterCallback: (value) => '音量 ${value.round()}%',
              ),
            ),
          ),
        ),
        SizedBox(width: compact ? 3 : 8),
        _SpeedMenu(
          currentSpeed: playbackSpeed,
          speeds: speeds,
          onSelected: onSpeedChanged,
        ),
        SizedBox(width: compact ? 3 : 8),
        _ControlIconButton(
          icon: fullscreen
              ? Icons.fullscreen_exit_rounded
              : Icons.fullscreen_rounded,
          tooltip: fullscreen ? '退出全屏' : '进入全屏',
          onPressed: onToggleFullscreen,
        ),
      ],
    );
  }
}

class _ControlIconButton extends StatelessWidget {
  const _ControlIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tooltip,
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        mouseCursor: SystemMouseCursors.click,
        icon: Icon(icon, size: 21),
        color: Colors.white.withValues(alpha: 0.82),
        hoverColor: Colors.white.withValues(alpha: 0.1),
        focusColor: AppTheme.primaryBlue.withValues(alpha: 0.18),
        highlightColor: Colors.white.withValues(alpha: 0.08),
        style: IconButton.styleFrom(
          minimumSize: const Size(38, 38),
          maximumSize: const Size(38, 38),
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }
}

class _PrimaryPlayButton extends StatelessWidget {
  const _PrimaryPlayButton({
    required this.playing,
    required this.onPressed,
  });

  final bool playing;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tooltip = playing ? '暂停' : '播放';
    return Semantics(
      button: true,
      label: tooltip,
      child: IconButton.filled(
        tooltip: tooltip,
        onPressed: onPressed,
        mouseCursor: SystemMouseCursors.click,
        icon: AnimatedSwitcher(
          key: const ValueKey('player-play-state-icon'),
          duration: const Duration(milliseconds: 160),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: Icon(
            playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
            key: ValueKey(playing),
            size: 25,
          ),
        ),
        color: Colors.white,
        style: IconButton.styleFrom(
          minimumSize: const Size(44, 44),
          maximumSize: const Size(44, 44),
          padding: EdgeInsets.zero,
          backgroundColor: AppTheme.primaryBlue,
          hoverColor: AppTheme.accentBlue,
          focusColor: AppTheme.accentBlue,
          highlightColor: AppTheme.primaryDark,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }
}

class _NextEpisodeButton extends StatelessWidget {
  const _NextEpisodeButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '播放下一集',
      child: Semantics(
        button: true,
        label: '播放下一集',
        child: TextButton.icon(
          onPressed: onPressed,
          icon: const Icon(Icons.skip_next_rounded, size: 19),
          label: const Text('下一集'),
          style: TextButton.styleFrom(
            foregroundColor: Colors.white.withValues(alpha: 0.82),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            minimumSize: const Size(0, 38),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(
                color: Colors.white.withValues(alpha: 0.12),
              ),
            ),
          ).copyWith(
            mouseCursor: const WidgetStatePropertyAll(
              SystemMouseCursors.click,
            ),
            overlayColor: WidgetStatePropertyAll(
              Colors.white.withValues(alpha: 0.08),
            ),
          ),
        ),
      ),
    );
  }
}

class _SpeedMenu extends StatelessWidget {
  const _SpeedMenu({
    required this.currentSpeed,
    required this.speeds,
    required this.onSelected,
  });

  final double currentSpeed;
  final List<double> speeds;
  final ValueChanged<double> onSelected;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '播放倍速',
      value: _formatSpeed(currentSpeed),
      child: PopupMenuButton<double>(
        tooltip: '倍速',
        color: context.colors.bgCard,
        surfaceTintColor: Colors.transparent,
        position: PopupMenuPosition.over,
        onSelected: onSelected,
        itemBuilder: (context) => speeds
            .map(
              (speed) => PopupMenuItem<double>(
                value: speed,
                height: 40,
                child: Row(
                  children: [
                    SizedBox(
                      width: 18,
                      child: speed == currentSpeed
                          ? const Icon(
                              Icons.check_rounded,
                              size: 17,
                              color: AppTheme.primaryBlue,
                            )
                          : null,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatSpeed(speed),
                      style: TextStyle(
                        color: speed == currentSpeed
                            ? AppTheme.accentBlue
                            : context.colors.textPrimary,
                        fontSize: 13,
                        fontWeight: speed == currentSpeed
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Container(
            height: 36,
            constraints: const BoxConstraints(minWidth: 52),
            padding: const EdgeInsets.symmetric(horizontal: 9),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
            child: Text(
              _formatSpeed(currentSpeed),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _formatDuration(Duration duration) {
  final value = duration.isNegative ? Duration.zero : duration;
  final hours = value.inHours;
  final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
  return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
}

String _formatSpeed(double speed) {
  if (speed == speed.roundToDouble()) {
    return '${speed.toStringAsFixed(1)}x';
  }
  return '${speed.toStringAsFixed(speed * 10 == (speed * 10).round() ? 1 : 2)}x';
}
