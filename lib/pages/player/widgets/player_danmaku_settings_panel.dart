import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';

class PlayerDanmakuSettingsPanel extends StatelessWidget {
  final bool visible;
  final double opacity;
  final double area;
  final double speed;
  final double fontScale;
  final VoidCallback onToggleVisible;
  final ValueChanged<double> onOpacityChanged;
  final ValueChanged<double> onAreaChanged;
  final ValueChanged<double> onSpeedChanged;
  final ValueChanged<double> onFontScaleChanged;

  const PlayerDanmakuSettingsPanel({
    super.key,
    required this.visible,
    required this.opacity,
    required this.area,
    required this.speed,
    required this.fontScale,
    required this.onToggleVisible,
    required this.onOpacityChanged,
    required this.onAreaChanged,
    required this.onSpeedChanged,
    required this.onFontScaleChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: '弹幕设置面板',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            width: 344,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFF0D1420).withValues(alpha: 0.90),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: AppTheme.primaryBlue.withValues(alpha: 0.16),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.12),
                  blurRadius: 34,
                  offset: const Offset(0, 18),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.34),
                  blurRadius: 28,
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
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryBlue.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.tune_rounded,
                        color: AppTheme.primaryBlue,
                        size: 21,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '弹幕设置',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            '调节观看时的弹幕存在感',
                            style: TextStyle(
                              color: Color(0xFF8C99AA),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _VisibilityChip(
                      visible: visible,
                      onTap: onToggleVisible,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _DanmakuTuningSlider(
                  label: '不透明度',
                  value: opacity,
                  min: 0.2,
                  max: 1,
                  display: '${(opacity * 100).round()}%',
                  onChanged: onOpacityChanged,
                ),
                _DanmakuTuningSlider(
                  label: '显示区域',
                  value: area,
                  min: 0.25,
                  max: 1,
                  display: '${(area * 100).round()}%',
                  onChanged: onAreaChanged,
                ),
                _DanmakuTuningSlider(
                  label: '滚动速度',
                  value: speed,
                  min: 0.5,
                  max: 3,
                  display: '${speed.toStringAsFixed(1)}x',
                  onChanged: onSpeedChanged,
                ),
                _DanmakuTuningSlider(
                  label: '字号',
                  value: fontScale,
                  min: 0.7,
                  max: 1.6,
                  display: '${fontScale.toStringAsFixed(1)}x',
                  onChanged: onFontScaleChanged,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _VisibilityChip extends StatefulWidget {
  final bool visible;
  final VoidCallback onTap;

  const _VisibilityChip({
    required this.visible,
    required this.onTap,
  });

  @override
  State<_VisibilityChip> createState() => _VisibilityChipState();
}

class _VisibilityChipState extends State<_VisibilityChip> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.visible;
    return Semantics(
      button: true,
      selected: active,
      label: active ? '隐藏弹幕' : '显示弹幕',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 170),
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: active
                  ? AppTheme.primaryBlue.withValues(alpha: _hovering ? 0.24 : 0.18)
                  : Colors.white.withValues(alpha: _hovering ? 0.12 : 0.07),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: active
                    ? AppTheme.primaryBlue.withValues(alpha: 0.35)
                    : Colors.white.withValues(alpha: 0.08),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  active ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                  color: active
                      ? AppTheme.primaryBlue
                      : Colors.white.withValues(alpha: 0.74),
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  active ? '显示' : '隐藏',
                  style: TextStyle(
                    color: active
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.72),
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DanmakuTuningSlider extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final String display;
  final ValueChanged<double> onChanged;

  const _DanmakuTuningSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.display,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.045),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.white.withValues(alpha: 0.065)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.76),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                Text(
                  display,
                  style: const TextStyle(
                    color: AppTheme.primaryBlue,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            SliderTheme(
              data: SliderThemeData(
                activeTrackColor: AppTheme.primaryBlue,
                inactiveTrackColor: Colors.white.withValues(alpha: 0.14),
                thumbColor: Colors.white,
                overlayColor: AppTheme.primaryBlue.withValues(alpha: 0.16),
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                trackHeight: 3,
              ),
              child: Slider(
                value: value,
                min: min,
                max: max,
                onChanged: onChanged,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
