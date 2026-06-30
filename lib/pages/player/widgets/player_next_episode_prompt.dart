import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';

class PlayerNextEpisodePrompt extends StatelessWidget {
  final String episodeName;
  final VoidCallback onPlay;
  final VoidCallback onDismiss;

  const PlayerNextEpisodePrompt({
    super.key,
    required this.episodeName,
    required this.onPlay,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: '下一集提示：$episodeName',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            width: 318,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFF0E1520).withValues(alpha: 0.86),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: AppTheme.primaryBlue.withValues(alpha: 0.22),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.13),
                  blurRadius: 30,
                  offset: const Offset(0, 14),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.36),
                  blurRadius: 26,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryBlue.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.skip_next_rounded,
                        color: AppTheme.primaryBlue,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        '即将播放',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: '关闭下一集提示',
                      onPressed: onDismiss,
                      icon: Icon(
                        Icons.close_rounded,
                        color: Colors.white.withValues(alpha: 0.62),
                        size: 18,
                      ),
                      style: IconButton.styleFrom(
                        minimumSize: const Size(34, 34),
                        fixedSize: const Size(34, 34),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ).copyWith(
                        mouseCursor:
                            WidgetStateProperty.all(SystemMouseCursors.click),
                        overlayColor: WidgetStateProperty.all(
                          Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  episodeName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.78),
                    fontSize: 13,
                    height: 1.45,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: 0.82,
                    minHeight: 4,
                    color: AppTheme.primaryBlue,
                    backgroundColor: Colors.white.withValues(alpha: 0.10),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '片尾即将结束，可直接续播',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.48),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: onPlay,
                      icon: const Icon(Icons.play_arrow_rounded, size: 18),
                      label: const Text('立即播放'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.primaryBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 11,
                        ),
                        textStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ).copyWith(
                        mouseCursor:
                            WidgetStateProperty.all(SystemMouseCursors.click),
                        overlayColor: WidgetStateProperty.all(
                          Colors.white.withValues(alpha: 0.10),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
