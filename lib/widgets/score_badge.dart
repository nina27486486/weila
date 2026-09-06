import 'package:flutter/material.dart';

import '../theme/vira_colors.dart';

/// 评分星 + 分数的统一展示。
///
/// 各页面的排版密度不同（卡片角标 / 列表行 / 排行榜），通过
/// [iconSize]、[spacing]、[textStyle] 保持原有视觉规格。
class ScoreBadge extends StatelessWidget {
  const ScoreBadge({
    super.key,
    required this.score,
    this.iconSize = 12,
    this.spacing = 2,
    this.textStyle,
    this.starColor,
  });

  final double score;

  /// 星标尺寸；卡片角标 12、列表 13、排行榜 15。
  final double iconSize;

  /// 星标与分数的间距。
  final double spacing;

  /// 分数文本样式；不传时使用卡片角标的白色粗体规格。
  final TextStyle? textStyle;

  /// 星标颜色；默认主题 warning 金色。
  final Color? starColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.star_rounded,
          size: iconSize,
          color: starColor ?? context.colors.warning,
        ),
        SizedBox(width: spacing),
        Text(
          score.toStringAsFixed(1),
          style: textStyle ??
              const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
        ),
      ],
    );
  }
}
