part of 'poster_rail.dart';

class _PosterRailScrollTrack extends StatelessWidget {
  final bool isDark;

  const _PosterRailScrollTrack({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      key: const ValueKey('poster-rail-scroll-track'),
      height: _posterRailScrollbarTrackHeight,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(
          _posterRailScrollbarTrackHeight / 2,
        ),
        gradient: LinearGradient(
          colors: [
            colors.paper.withValues(alpha: isDark ? 0.34 : 0.76),
            colors.skyLight.withValues(alpha: isDark ? 0.72 : 0.84),
            colors.paper.withValues(alpha: isDark ? 0.28 : 0.70),
          ],
        ),
        border: Border.all(
          color: colors.sky.withValues(alpha: isDark ? 0.34 : 0.22),
        ),
      ),
    );
  }
}

class _PosterRailScrollThumbVisual extends StatelessWidget {
  final bool active;
  final bool isDark;
  final bool motionEnabled;

  const _PosterRailScrollThumbVisual({
    required this.active,
    required this.isDark,
    required this.motionEnabled,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Align(
      child: AnimatedContainer(
        key: const ValueKey('poster-rail-scroll-thumb-visual'),
        duration: motionEnabled ? AppAnimations.fast : Duration.zero,
        curve: AppAnimations.easeOut,
        height: _posterRailScrollbarThumbVisualHeight,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(
            _posterRailScrollbarThumbVisualHeight / 2,
          ),
          gradient: LinearGradient(
            colors: [
              colors.skyLight.withValues(alpha: active ? 1 : 0.88),
              colors.sky.withValues(alpha: active ? 1 : 0.92),
              Color.lerp(
                colors.sky,
                Colors.white,
                active ? 0.52 : 0.42,
              )!,
            ],
          ),
          border: Border.all(
            color: Colors.white.withValues(
              alpha: active ? (isDark ? 0.82 : 1) : (isDark ? 0.62 : 0.88),
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: colors.sky.withValues(
                alpha: active ? (isDark ? 0.42 : 0.30) : (isDark ? 0.26 : 0.18),
              ),
              blurRadius: active ? 14 : 8,
            ),
          ],
        ),
      ),
    );
  }
}

class _PosterRailScrollbarMascot extends StatelessWidget {
  const _PosterRailScrollbarMascot();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: -14,
      child: IgnorePointer(
        child: Image.asset(
          'assets/images/scrollbar_navigator.webp',
          key: const ValueKey('poster-rail-scroll-mascot'),
          width: _posterRailScrollbarMascotSize,
          height: _posterRailScrollbarMascotSize,
          filterQuality: FilterQuality.high,
        ),
      ),
    );
  }
}
