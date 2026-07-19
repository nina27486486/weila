import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

class PlayerControls extends StatelessWidget {
  final Duration position;
  final Duration duration;
  final ValueChanged<double> onSeek;

  const PlayerControls({
    super.key,
    required this.position,
    required this.duration,
    required this.onSeek,
  });

  static String formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (hours > 0) {
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.black87, Colors.transparent],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(
                  formatDuration(position),
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                Expanded(
                  child: SliderTheme(
                    data: SliderThemeData(
                      activeTrackColor: AppTheme.primaryBlue,
                      inactiveTrackColor: Colors.white24,
                      thumbColor: AppTheme.primaryBlue,
                      overlayColor: AppTheme.primaryBlue.withValues(alpha: 0.2),
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                      trackHeight: 3,
                    ),
                    child: Slider(
                      value: duration.inMilliseconds > 0
                          ? position.inMilliseconds / duration.inMilliseconds
                          : 0,
                      onChanged: onSeek,
                    ),
                  ),
                ),
                Text(
                  formatDuration(duration),
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
