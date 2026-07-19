import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';

class PlayerDiagnosticIssue {
  final IconData icon;
  final String title;
  final String message;

  const PlayerDiagnosticIssue({
    required this.icon,
    required this.title,
    required this.message,
  });
}

class PlayerLoadingOverlay extends StatelessWidget {
  final String title;
  final String? subtitle;

  const PlayerLoadingOverlay({
    super.key,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: subtitle == null ? title : '$title，$subtitle',
      liveRegion: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            constraints: const BoxConstraints(minWidth: 260),
            padding: const EdgeInsets.fromLTRB(20, 18, 22, 18),
            decoration: BoxDecoration(
              color: const Color(0xFF0D1420).withValues(alpha: 0.80),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: AppTheme.primaryBlue.withValues(alpha: 0.20),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.12),
                  blurRadius: 28,
                  offset: const Offset(0, 14),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.30),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 34,
                  height: 34,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.primaryBlue.withValues(alpha: 0.10),
                        ),
                      ),
                      const SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(
                          color: AppTheme.primaryBlue,
                          strokeWidth: 2.6,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.58),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
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

class PlayerDiagnosticsOverlay extends StatelessWidget {
  final PlayerDiagnosticIssue issue;
  final int currentSourceIndex;
  final int sourceCount;
  final Duration position;
  final VoidCallback onRetry;
  final VoidCallback? onSwitchSource;
  final VoidCallback onBack;

  const PlayerDiagnosticsOverlay({
    super.key,
    required this.issue,
    this.currentSourceIndex = 0,
    this.sourceCount = 1,
    this.position = Duration.zero,
    required this.onRetry,
    this.onSwitchSource,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      child: Semantics(
        container: true,
        label: '播放器播放诊断：${issue.title}',
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0.12, -0.18),
              radius: 1.08,
              colors: [
                AppTheme.primaryBlue.withValues(alpha: 0.16),
                const Color(0xE6080B12),
                const Color(0xF4000000),
              ],
              stops: const [0, 0.54, 1],
            ),
          ),
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(28, 26, 28, 24),
                      decoration: BoxDecoration(
                        color: const Color(0xFF111722).withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: AppTheme.primaryBlue.withValues(alpha: 0.18),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color:
                                AppTheme.primaryBlue.withValues(alpha: 0.16),
                            blurRadius: 42,
                            spreadRadius: -12,
                            offset: const Offset(0, 18),
                          ),
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.42),
                            blurRadius: 36,
                            offset: const Offset(0, 22),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              _DiagnosticBadge(icon: issue.icon),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primaryBlue
                                            .withValues(alpha: 0.14),
                                        borderRadius: BorderRadius.circular(99),
                                      ),
                                      child: const Text(
                                        '播放诊断',
                                        style: TextStyle(
                                          color: AppTheme.primaryBlue,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 1.3,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      issue.title,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 22,
                                        height: 1.18,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          Text(
                            issue.message,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.72),
                              fontSize: 13,
                              height: 1.65,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              _DiagnosticMetricChip(
                                icon: Icons.route_rounded,
                                label: _sourceLabel,
                              ),
                              _DiagnosticMetricChip(
                                icon: Icons.schedule_rounded,
                                label: '进度 ${_formatDuration(position)}',
                              ),
                              const _DiagnosticMetricChip(
                                icon: Icons.auto_fix_high_rounded,
                                label: '已尝试自动恢复',
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.045),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.07),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '建议操作',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.88),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                _HintLine(
                                  text: onSwitchSource == null
                                      ? '先重新加载当前进度；如果仍然失败，返回详情页更换播放源。'
                                      : '优先重新加载当前进度；如果仍然黑屏或卡住，切换到下一条线路。',
                                ),
                                const SizedBox(height: 6),
                                const _HintLine(
                                  text: '如果只有声音没有画面，通常是该线路编码或硬解码兼容性异常。',
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 22),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              FilledButton.icon(
                                onPressed: onRetry,
                                icon:
                                    const Icon(Icons.refresh_rounded, size: 18),
                                label: const Text('重新加载'),
                                style: _primaryButtonStyle,
                              ),
                              if (onSwitchSource != null)
                                OutlinedButton.icon(
                                  onPressed: onSwitchSource,
                                  icon: const Icon(
                                    Icons.swap_horiz_rounded,
                                    size: 18,
                                  ),
                                  label: const Text('切换线路'),
                                  style: _outlinedButtonStyle,
                                ),
                              TextButton.icon(
                                onPressed: onBack,
                                icon: const Icon(
                                  Icons.arrow_back_rounded,
                                  size: 18,
                                ),
                                label: const Text('返回详情'),
                                style: _textButtonStyle,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String get _sourceLabel {
    final safeCount = sourceCount <= 0 ? 1 : sourceCount;
    final safeIndex = currentSourceIndex.clamp(0, safeCount - 1) + 1;
    return '线路 $safeIndex/$safeCount';
  }

  static String _formatDuration(Duration value) {
    final hours = value.inHours;
    final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (hours > 0) return '$hours:$minutes:$seconds';
    return '$minutes:$seconds';
  }

  static ButtonStyle get _primaryButtonStyle => FilledButton.styleFrom(
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ).copyWith(
        mouseCursor: WidgetStateProperty.all(SystemMouseCursors.click),
        overlayColor: WidgetStateProperty.all(
          Colors.white.withValues(alpha: 0.10),
        ),
      );

  static ButtonStyle get _outlinedButtonStyle => OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: BorderSide(color: AppTheme.primaryBlue.withValues(alpha: 0.42)),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ).copyWith(
        mouseCursor: WidgetStateProperty.all(SystemMouseCursors.click),
        overlayColor: WidgetStateProperty.all(
          AppTheme.primaryBlue.withValues(alpha: 0.12),
        ),
      );

  static ButtonStyle get _textButtonStyle => TextButton.styleFrom(
        foregroundColor: Colors.white.withValues(alpha: 0.66),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ).copyWith(
        mouseCursor: WidgetStateProperty.all(SystemMouseCursors.click),
        overlayColor: WidgetStateProperty.all(
          Colors.white.withValues(alpha: 0.08),
        ),
      );
}

class _DiagnosticBadge extends StatelessWidget {
  final IconData icon;

  const _DiagnosticBadge({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 66,
      height: 66,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryBlue.withValues(alpha: 0.34),
            const Color(0xFF1E293B).withValues(alpha: 0.72),
          ],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryBlue.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: 30),
    );
  }
}

class _DiagnosticMetricChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _DiagnosticMetricChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1220).withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppTheme.primaryBlue, size: 15),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.76),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _HintLine extends StatelessWidget {
  final String text;

  const _HintLine({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 5,
          height: 5,
          margin: const EdgeInsets.only(top: 8),
          decoration: const BoxDecoration(
            color: AppTheme.primaryBlue,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.58),
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}
