import 'package:flutter/material.dart';
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
  int _previousIndex = 0;
  late final PageController _pageController;
  late final AnimationController _progressController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
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
      duration: const Duration(milliseconds: 600),
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
        height: 280,
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Text('暂无推荐', style: TextStyle(color: AppTheme.textMuted)),
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
        height: 280,
        child: Stack(
          children: [
            // 页面视图
            PageView.builder(
              controller: _pageController,
              itemCount: widget.items.length,
              onPageChanged: (i) {
                setState(() {
                  _previousIndex = _currentIndex;
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
                      scale: 0.9 + value * 0.1,
                      child: Opacity(
                        opacity: value,
                        child: child,
                      ),
                    );
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppTheme.bgCard,
                          AppTheme.primaryDark.withValues(alpha: 0.6),
                        ],
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // 封面图（带Referer防盗链）
                        CoverImage(url: item.imageUrl, fit: BoxFit.cover),
                        // 暗色遮罩
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.3),
                                Colors.black.withValues(alpha: 0.7),
                              ],
                              stops: const [0.4, 1.0],
                            ),
                          ),
                        ),
                        // 内容
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: 6,
                                children: [
                                  _buildTag('追番中', AppTheme.tagHighlight),
                                  ...item.tags.take(3).map((t) => _buildTag(t, AppTheme.tagBg)),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                item.title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  shadows: [Shadow(blurRadius: 8, color: Colors.black54)],
                                ),
                              ),
                              if (item.description != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  item.description!,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.8),
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  _HoverButton(
                                    onPressed: item.onPlay,
                                    icon: Icons.play_arrow,
                                    label: '立即播放',
                                    filled: true,
                                  ),
                                  const SizedBox(width: 12),
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
              bottom: 16,
              right: 24,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                  widget.items.length,
                  (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    width: i == _currentIndex ? 24 : 6,
                    height: 6,
                    margin: const EdgeInsets.only(left: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3),
                      color: i == _currentIndex
                          ? AppTheme.primaryBlue
                          : AppTheme.textMuted.withValues(alpha: 0.4),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
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
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedScale(
        scale: _hovering ? 1.05 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        child: widget.filled
            ? FilledButton.icon(
                onPressed: widget.onPressed,
                icon: Icon(widget.icon, size: 20),
                label: Text(widget.label),
                style: FilledButton.styleFrom(
                  backgroundColor: _hovering
                      ? AppTheme.accentBlue
                      : AppTheme.primaryBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
                    color: _hovering ? AppTheme.primaryBlue : AppTheme.divider,
                  ),
                  backgroundColor: _hovering
                      ? AppTheme.primaryBlue.withValues(alpha: 0.1)
                      : Colors.transparent,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  animationDuration: const Duration(milliseconds: 200),
                ),
              ),
      ),
    );
  }
}
