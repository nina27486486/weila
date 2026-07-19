import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../services/danmaku/danmaku_load_result.dart';
import '../../../services/danmaku/danmaku_matcher.dart';
import '../../../theme/app_theme.dart';

class PlayerDanmakuSettingsPanel extends StatelessWidget {
  final bool visible;
  final double opacity;
  final double area;
  final double speed;
  final double fontScale;
  final DanmakuLoadResult? loadResult;
  final VoidCallback onToggleVisible;
  final ValueChanged<double> onOpacityChanged;
  final ValueChanged<double> onAreaChanged;
  final ValueChanged<double> onSpeedChanged;
  final ValueChanged<double> onFontScaleChanged;
  final VoidCallback? onRefresh;
  final ValueChanged<DanmakuMatchCandidate>? onCandidateSelected;

  const PlayerDanmakuSettingsPanel({
    super.key,
    required this.visible,
    required this.opacity,
    required this.area,
    required this.speed,
    required this.fontScale,
    this.loadResult,
    required this.onToggleVisible,
    required this.onOpacityChanged,
    required this.onAreaChanged,
    required this.onSpeedChanged,
    required this.onFontScaleChanged,
    this.onRefresh,
    this.onCandidateSelected,
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
            child: SingleChildScrollView(
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
                  if (loadResult != null) ...[
                    _DanmakuLoadStatusCard(
                      result: loadResult!,
                      onRefresh: onRefresh,
                      onCandidateSelected: onCandidateSelected,
                    ),
                    const SizedBox(height: 14),
                  ],
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
      ),
    );
  }
}

class _DanmakuLoadStatusCard extends StatelessWidget {
  const _DanmakuLoadStatusCard({
    required this.result,
    this.onRefresh,
    this.onCandidateSelected,
  });

  final DanmakuLoadResult result;
  final VoidCallback? onRefresh;
  final ValueChanged<DanmakuMatchCandidate>? onCandidateSelected;

  @override
  Widget build(BuildContext context) {
    final loading = result.status == DanmakuLoadStatus.searching ||
        result.status == DanmakuLoadStatus.loading;
    final title = switch (result.status) {
      DanmakuLoadStatus.notConfigured => '未配置弹幕服务',
      DanmakuLoadStatus.searching => '正在搜索匹配剧集',
      DanmakuLoadStatus.ambiguous => '请选择匹配剧集',
      DanmakuLoadStatus.loading => '正在加载真实弹幕',
      DanmakuLoadStatus.loaded => '已加载 ${result.items.length} 条弹幕',
      DanmakuLoadStatus.noMatch => '未找到匹配弹幕',
      DanmakuLoadStatus.authFailed => '凭证验证失败',
      DanmakuLoadStatus.quotaExceeded => '今日调用额度已用完',
      DanmakuLoadStatus.networkFailed => '弹幕服务连接失败',
      DanmakuLoadStatus.malformedResponse => '弹幕数据格式异常',
    };
    final isError = switch (result.status) {
      DanmakuLoadStatus.authFailed ||
      DanmakuLoadStatus.quotaExceeded ||
      DanmakuLoadStatus.networkFailed ||
      DanmakuLoadStatus.malformedResponse =>
        true,
      _ => false,
    };
    final accent = isError ? const Color(0xFFFF8A80) : AppTheme.primaryBlue;

    return Semantics(
      liveRegion: true,
      label: title,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.09),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: accent.withValues(alpha: 0.22)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (loading)
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: accent,
                    ),
                  )
                else
                  Icon(
                    isError
                        ? Icons.error_outline_rounded
                        : Icons.subtitles_rounded,
                    size: 17,
                    color: accent,
                  ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (!loading && onRefresh != null)
                  TextButton(
                    onPressed: onRefresh,
                    child: const Text('刷新匹配'),
                  ),
              ],
            ),
            if (result.safeMessage != null && result.safeMessage!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  result.safeMessage!,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.66),
                    fontSize: 11,
                  ),
                ),
              ),
            if (result.status == DanmakuLoadStatus.ambiguous)
              ...result.candidates.map(
                (candidate) => Semantics(
                  button: true,
                  label: '选择 ${candidate.animeTitle} ${candidate.episodeTitle}',
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: onCandidateSelected == null
                          ? null
                          : () => onCandidateSelected!(candidate),
                      child: Padding(
                        padding: const EdgeInsets.all(9),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    candidate.animeTitle,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${candidate.episodeTitle} · ${candidate.typeDescription}',
                                    style: TextStyle(
                                      color:
                                          Colors.white.withValues(alpha: 0.58),
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: AppTheme.primaryBlue,
                              size: 18,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
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
                  ? AppTheme.primaryBlue
                      .withValues(alpha: _hovering ? 0.24 : 0.18)
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
                  active
                      ? Icons.visibility_rounded
                      : Icons.visibility_off_rounded,
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
