import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/animations.dart';
import '../utils/helpers.dart';
import '../widgets/cover_image.dart';

/// 动漫卡片 - 用于新番/热门推荐展示（带悬停动画）
class AnimeCard extends StatefulWidget {
  final String title;
  final String? coverUrl;
  final double? score;
  final List<String>? tags;
  final String? badge;
  final Color? badgeColor;
  final VoidCallback? onTap;

  const AnimeCard({
    super.key,
    required this.title,
    this.coverUrl,
    this.score,
    this.tags,
    this.badge,
    this.badgeColor,
    this.onTap,
  });

  @override
  State<AnimeCard> createState() => _AnimeCardState();
}

class _AnimeCardState extends State<AnimeCard> with SingleTickerProviderStateMixin {
  bool _hovering = false;
  late final AnimationController _badgeController;
  late final Animation<double> _badgeScale;

  @override
  void initState() {
    super.initState();
    _badgeController = AnimationController(
      vsync: this,
      duration: AppAnimations.normal,
    );
    _badgeScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _badgeController, curve: AppAnimations.bounce),
    );
    _badgeController.forward();
  }

  @override
  void dispose() {
    _badgeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: AppAnimations.easeOut,
          transform: _hovering
              ? (Matrix4.identity()..translate(0.0, -4.0))
              : Matrix4.identity(),
          width: 150,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 封面图
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: AppAnimations.easeOut,
                width: 150,
                height: 200,
                decoration: BoxDecoration(
                  color: AppTheme.bgCard,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: _hovering
                      ? [
                          BoxShadow(
                            color: AppTheme.primaryBlue.withValues(alpha: 0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ]
                      : [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // 封面图（带URL修复、Referer防盗链、错误处理）
                      CoverImage(
                        url: widget.coverUrl,
                        fit: BoxFit.cover,
                      ),
                    // 悬停时的播放图标叠加层
                    AnimatedOpacity(
                      opacity: _hovering ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Center(
                          child: Icon(Icons.play_circle_fill, size: 48, color: Colors.white),
                        ),
                      ),
                    ),
                    // 评分
                    if (widget.score != null)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: AnimatedScale(
                          scale: _hovering ? 1.1 : 1.0,
                          duration: const Duration(milliseconds: 200),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _getScoreColor(widget.score!).withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              widget.score!.toStringAsFixed(1),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    // 标签/徽章
                    if (widget.badge != null)
                      Positioned(
                        top: 6,
                        left: 6,
                        child: ScaleTransition(
                          scale: _badgeScale,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: (widget.badgeColor ?? AppTheme.tagHighlight).withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              widget.badge!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              ),
              const SizedBox(height: 8),
              // 标题
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  color: _hovering ? AppTheme.primaryBlue : AppTheme.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  height: 1.3,
                ),
                child: Text(widget.title, maxLines: 2, overflow: TextOverflow.ellipsis),
              ),
              // 标签
              if (widget.tags != null && widget.tags!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Wrap(
                    spacing: 4,
                    children: widget.tags!.take(3).map((tag) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppTheme.tagBg,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        tag,
                        style: const TextStyle(color: AppTheme.textMuted, fontSize: 10),
                      ),
                    )).toList(),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getScoreColor(double score) {
    if (score >= 9.0) return AppTheme.scoreGreen;
    if (score >= 7.5) return AppTheme.scoreOrange;
    return AppTheme.scoreRed;
  }
}
