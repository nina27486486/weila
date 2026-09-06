import 'package:flutter/material.dart';

import '../../theme/vira_colors.dart';
import '../cover_image.dart';
import '../score_badge.dart';
import 'artwork_card.dart';
import 'artwork_models.dart';

/// [ArtworkCardSurface] 的标准封面卡片内容：
/// hover 缩放封面 + 左上序号角标 + 右上评分角标 + 底部标题/副标题两行。
///
/// [keyPrefix]/[keyId] 用于生成稳定 ValueKey（`{prefix}-cover-clip-{id}` 等），
/// 保持页面测试与既有 key 语义不变。
class ArtworkCoverCard extends StatelessWidget {
  const ArtworkCoverCard({
    super.key,
    required this.interaction,
    required this.coverUrl,
    required this.keyPrefix,
    required this.keyId,
    required this.title,
    required this.subtitle,
    this.rankIndex,
    this.score,
  });

  /// 来自 ArtworkCardSurface contentBuilder 的交互状态。
  final ArtworkCardInteraction interaction;

  final String? coverUrl;

  /// ValueKey 前缀，如 'catalog' / 'archive'。
  final String keyPrefix;

  /// ValueKey 标识，如列表 index 或条目 id。
  final Object keyId;

  /// 非空时显示左上角标（1 起的序号）。
  final int? rankIndex;

  /// 非空时显示右上评分角标。
  final double? score;

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                child: ClipRect(
                  key: ValueKey('$keyPrefix-cover-clip-$keyId'),
                  clipBehavior: Clip.hardEdge,
                  child: AnimatedScale(
                    key: ValueKey('$keyPrefix-cover-scale-$keyId'),
                    duration: interaction.duration,
                    curve: Curves.easeOutCubic,
                    scale: interaction.coverScale,
                    child: CoverImage(url: coverUrl, fit: BoxFit.cover),
                  ),
                ),
              ),
              if (rankIndex != null)
                Positioned(
                  left: 9,
                  top: 9,
                  child: ArtworkCardBadge(
                    key: ValueKey('$keyPrefix-rank-$keyId'),
                    child: Text(
                      '${rankIndex! + 1}'.padLeft(2, '0'),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: colors.sky,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                ),
              if (score != null)
                Positioned(
                  right: 9,
                  top: 9,
                  child: ArtworkCardBadge(
                    key: ValueKey('$keyPrefix-score-$keyId'),
                    dark: true,
                    child: ScoreBadge(score: score!),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(11, 10, 11, 11),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 5),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
