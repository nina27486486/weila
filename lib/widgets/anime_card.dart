import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/vira_colors.dart';
import '../utils/animations.dart';
import 'cover_image.dart';

/// 内容优先的动漫卡片。悬停只改变层级，不移动整张卡片。
class AnimeCard extends StatefulWidget {
  const AnimeCard({
    super.key,
    required this.title,
    this.coverUrl,
    this.score,
    this.tags,
    this.badge,
    this.badgeColor,
    this.onTap,
    this.meta,
    this.compact = false,
  });

  final String title;
  final String? coverUrl;
  final double? score;
  final List<String>? tags;
  final String? badge;
  final Color? badgeColor;
  final VoidCallback? onTap;
  final String? meta;
  final bool compact;

  @override
  State<AnimeCard> createState() => _AnimeCardState();
}

class _AnimeCardState extends State<AnimeCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final cardWidth = widget.compact ? 136.0 : 158.0;
    final coverHeight = widget.compact ? 182.0 : 208.0;
    return Semantics(
      button: widget.onTap != null,
      label: '查看${widget.title}',
      child: MouseRegion(
        cursor:
            widget.onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: SizedBox(
            width: cardWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedContainer(
                  duration: AppAnimations.fast,
                  curve: AppAnimations.easeOut,
                  width: cardWidth,
                  height: coverHeight,
                  decoration: BoxDecoration(
                    color: context.colors.bgCard,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(
                      color: _hovering
                          ? AppTheme.primaryBlue.withValues(alpha: 0.42)
                          : context.colors.divider,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black
                            .withValues(alpha: _hovering ? 0.28 : 0.18),
                        blurRadius: _hovering ? 16 : 10,
                        offset: Offset(0, _hovering ? 8 : 5),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      AnimatedScale(
                        scale: _hovering ? 1.018 : 1,
                        duration: AppAnimations.normal,
                        curve: AppAnimations.easeOut,
                        child:
                            CoverImage(url: widget.coverUrl, fit: BoxFit.cover),
                      ),
                      const Positioned.fill(child: _CoverScrim()),
                      if (widget.badge != null)
                        Positioned(
                          top: 8,
                          left: 8,
                          child: _Badge(
                            label: widget.badge!,
                            color: widget.badgeColor ?? AppTheme.tagHighlight,
                          ),
                        ),
                      if (widget.score != null)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: _ScoreBadge(
                            score: widget.score!,
                            color: _scoreColor(widget.score!),
                          ),
                        ),
                      Positioned(
                        right: 8,
                        bottom: 8,
                        child: IgnorePointer(
                          ignoring: !_hovering,
                          child: AnimatedOpacity(
                            opacity: _hovering ? 1 : 0,
                            duration: AppAnimations.fast,
                            child: AnimatedSlide(
                              offset: _hovering
                                  ? Offset.zero
                                  : const Offset(0, 0.15),
                              duration: AppAnimations.fast,
                              curve: AppAnimations.easeOut,
                              child: Container(
                                height: 30,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 10),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryBlue,
                                  borderRadius: BorderRadius.circular(7),
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          Colors.black.withValues(alpha: 0.24),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.play_arrow_rounded,
                                        size: 17, color: Colors.white),
                                    SizedBox(width: 3),
                                    Text(
                                      '播放',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600),
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
                const SizedBox(height: 9),
                AnimatedDefaultTextStyle(
                  duration: AppAnimations.fast,
                  style: Theme.of(context).textTheme.titleSmall!.copyWith(
                        color: _hovering
                            ? AppTheme.accentBlue
                            : context.colors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                  child: Text(widget.title,
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                ),
                if (widget.meta case final meta? when meta.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                if (widget.tags case final tags? when tags.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Text(
                      tags.take(3).join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: context.colors.textMuted,
                            fontSize: 10,
                          ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _scoreColor(double score) {
    if (score >= 9) return AppTheme.scoreGreen;
    if (score >= 7.5) return AppTheme.scoreOrange;
    return AppTheme.scoreRed;
  }
}

class _CoverScrim extends StatelessWidget {
  const _CoverScrim();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.62)],
          stops: const [0.62, 1],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.90),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: const TextStyle(
            color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _ScoreBadge extends StatelessWidget {
  const _ScoreBadge({required this.score, required this.color});

  final double score;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_rounded, size: 12, color: color),
          const SizedBox(width: 3),
          Text(
            score.toStringAsFixed(1),
            style: const TextStyle(
                color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
