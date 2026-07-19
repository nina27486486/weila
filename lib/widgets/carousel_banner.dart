import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/vira_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/cover_image.dart';

class CarouselItem {
  final String title;
  final String? imageUrl;
  final List<String> tags;
  final String? description;
  final VoidCallback? onPlay;
  final VoidCallback? onDetail;

  const CarouselItem({
    required this.title,
    this.imageUrl,
    this.tags = const [],
    this.description,
    this.onPlay,
    this.onDetail,
  });
}

/// 轮播横幅 - 首页顶部大图轮播（带平滑动画）
class CarouselBanner extends StatefulWidget {
  final List<CarouselItem> items;

  const CarouselBanner({super.key, required this.items});

  @override
  State<CarouselBanner> createState() => _CarouselBannerState();
}

class _CarouselBannerState extends State<CarouselBanner>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  late final PageController _pageController;
  late final AnimationController _progressController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _progressController = AnimationController(
      vsync: this,
      duration: Duration(seconds: 5),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _goToNext();
        }
      });
    _progressController.forward();
  }

  void _goToNext() {
    if (!mounted || widget.items.isEmpty) return;
    final next = (_currentIndex + 1) % widget.items.length;
    _pageController.animateToPage(
      next,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return Container(
        height: 340,
        decoration: BoxDecoration(
          color: context.colors.bgCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: context.colors.divider),
        ),
        child: Center(
          child:
              Text('暂无推荐', style: TextStyle(color: context.colors.textMuted)),
        ),
      );
    }

    return MouseRegion(
      onEnter: (_) => _progressController.stop(),
      onExit: (_) {
        _progressController.reset();
        _progressController.forward();
      },
      child: SizedBox(
        height: 340,
        child: Stack(
          children: [
            // 页面视图
            PageView.builder(
              controller: _pageController,
              itemCount: widget.items.length,
              onPageChanged: (i) {
                setState(() {
                  _currentIndex = i;
                });
                _progressController.reset();
                _progressController.forward();
              },
              itemBuilder: (context, index) {
                final item = widget.items[index];
                return AnimatedBuilder(
                  animation: _pageController,
                  builder: (context, child) {
                    double value = 1.0;
                    if (_pageController.position.haveDimensions) {
                      value = _pageController.page! - index;
                      value = (1 - value.abs()).clamp(0.0, 1.0);
                    }
                    return Transform.scale(
                      scale: 0.985 + value * 0.015,
                      child: Opacity(
                        opacity: value,
                        child: child,
                      ),
                    );
                  },
                  child: Container(
                    margin: EdgeInsets.zero,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          context.colors.bgCard,
                          context.colors.bgCard,
                          AppTheme.primaryBlue.withValues(alpha: 0.10),
                        ],
                      ),
                      border: Border.all(color: context.colors.divider),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.20),
                          blurRadius: 18,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ImageFiltered(
                          imageFilter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                          child: Transform.scale(
                            scale: 1.12,
                            child: CoverImage(
                                url: item.imageUrl, fit: BoxFit.cover),
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [
                                Colors.black.withValues(alpha: 0.88),
                                context.colors.bgCard.withValues(alpha: 0.72),
                                Colors.black.withValues(alpha: 0.18),
                              ],
                              stops: const [0.0, 0.52, 1.0],
                            ),
                          ),
                        ),
                        Positioned(
                          top: 22,
                          right: 34,
                          bottom: 26,
                          child: _HeroPoster(
                            imageUrl: item.imageUrl,
                            indexText: '${index + 1}'.padLeft(2, '0'),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(32, 28, 340, 30),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  _buildTag('今日主推', AppTheme.primaryBlue),
                                  ...item.tags.take(3).map((t) =>
                                      _buildTag(t, context.colors.tagBg)),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Text(
                                item.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 32,
                                  fontWeight: FontWeight.w700,
                                  height: 1.08,
                                  shadows: const [
                                    Shadow(
                                        blurRadius: 12, color: Colors.black87)
                                  ],
                                ),
                              ),
                              if (item.description != null) ...[
                                const SizedBox(height: 10),
                                Text(
                                  item.description!,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.78),
                                    fontSize: 14,
                                    height: 1.45,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 20),
                              Row(
                                children: [
                                  _HoverButton(
                                    onPressed: item.onPlay ?? item.onDetail,
                                    icon: Icons.play_arrow,
                                    label: '立即播放',
                                    filled: true,
                                  ),
                                  SizedBox(width: 12),
                                  _HoverButton(
                                    onPressed: item.onDetail,
                                    icon: Icons.info_outline,
                                    label: '详情',
                                    filled: false,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

            // 指示器（带进度条动画）
            Positioned(
              bottom: 22,
              right: 36,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                  widget.items.length,
                  (i) => AnimatedContainer(
                    duration: Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    width: i == _currentIndex ? 24 : 5,
                    height: 4,
                    margin: const EdgeInsets.only(left: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3),
                      color: i == _currentIndex
                          ? AppTheme.primaryBlue
                          : context.colors.textMuted.withValues(alpha: 0.4),
                    ),
                    child: i == _currentIndex
                        ? AnimatedBuilder(
                            animation: _progressController,
                            builder: (context, _) {
                              return FractionallySizedBox(
                                alignment: Alignment.centerLeft,
                                widthFactor: _progressController.value,
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(3),
                                    color: AppTheme.accentBlue,
                                  ),
                                ),
                              );
                            },
                          )
                        : null,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _HeroPoster extends StatelessWidget {
  final String? imageUrl;
  final String indexText;

  const _HeroPoster({
    required this.imageUrl,
    required this.indexText,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 214,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: -18,
            top: 28,
            child: Text(
              indexText,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.08),
                fontSize: 96,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryBlue.withValues(alpha: 0.2),
                    blurRadius: 28,
                    offset: const Offset(0, 18),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: CoverImage(url: imageUrl, fit: BoxFit.cover),
            ),
          ),
        ],
      ),
    );
  }
}

/// 轮播按钮（悬停效果）
class _HoverButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final IconData icon;
  final String label;
  final bool filled;

  const _HoverButton({
    required this.onPressed,
    required this.icon,
    required this.label,
    required this.filled,
  });

  @override
  State<_HoverButton> createState() => _HoverButtonState();
}

class _HoverButtonState extends State<_HoverButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          boxShadow: widget.filled && _hovering
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.22),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ]
              : null,
        ),
        child: widget.filled
            ? FilledButton.icon(
                onPressed: widget.onPressed,
                icon: Icon(widget.icon, size: 20),
                label: Text(widget.label),
                style: FilledButton.styleFrom(
                  backgroundColor:
                      _hovering ? AppTheme.accentBlue : AppTheme.primaryBlue,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  animationDuration: const Duration(milliseconds: 200),
                ),
              )
            : OutlinedButton.icon(
                onPressed: widget.onPressed,
                icon: Icon(widget.icon, size: 18),
                label: Text(widget.label),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(
                    color: _hovering
                        ? AppTheme.primaryBlue
                        : context.colors.divider,
                  ),
                  backgroundColor: _hovering
                      ? AppTheme.primaryBlue.withValues(alpha: 0.1)
                      : Colors.transparent,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  animationDuration: const Duration(milliseconds: 200),
                ),
              ),
      ),
    );
  }
}
