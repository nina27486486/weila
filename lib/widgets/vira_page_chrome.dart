import 'package:flutter/material.dart';

import '../theme/vira_colors.dart';
import 'liquid_glass_surface.dart';

enum ViraDestination { home, discover, following, library, downloads }

extension on ViraDestination {
  String get label => switch (this) {
        ViraDestination.home => '首页',
        ViraDestination.discover => '发现',
        ViraDestination.following => '追番',
        ViraDestination.library => '资料库',
        ViraDestination.downloads => '下载',
      };
}

/// 全站页面骨架。桌面端使用稳定刊头，页面只负责提供主体内容。
class ViraPageScaffold extends StatelessWidget {
  final ViraDestination? activeDestination;
  final ValueChanged<ViraDestination> onDestinationSelected;
  final VoidCallback onSearch;
  final VoidCallback onThemeToggle;
  final VoidCallback onProfile;
  final Widget child;
  final bool constrainContent;

  const ViraPageScaffold({
    super.key,
    required this.activeDestination,
    required this.onDestinationSelected,
    required this.onSearch,
    required this.onThemeToggle,
    required this.onProfile,
    required this.child,
    this.constrainContent = true,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.bgDark,
      body: SafeArea(
        child: Column(
          children: [
            _Masthead(
              activeDestination: activeDestination,
              onDestinationSelected: onDestinationSelected,
              onSearch: onSearch,
              onThemeToggle: onThemeToggle,
              onProfile: onProfile,
            ),
            Expanded(
              child: constrainContent
                  ? LayoutBuilder(
                      builder: (context, constraints) {
                        final horizontal = switch (constraints.maxWidth) {
                          >= 1440 => 56.0,
                          >= 1180 => 32.0,
                          _ => 20.0,
                        };
                        return Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1488),
                            child: Padding(
                              padding:
                                  EdgeInsets.symmetric(horizontal: horizontal),
                              child: child,
                            ),
                          ),
                        );
                      },
                    )
                  : child,
            ),
          ],
        ),
      ),
    );
  }
}

class _Masthead extends StatefulWidget {
  final ViraDestination? activeDestination;
  final ValueChanged<ViraDestination> onDestinationSelected;
  final VoidCallback onSearch;
  final VoidCallback onThemeToggle;
  final VoidCallback onProfile;

  const _Masthead({
    required this.activeDestination,
    required this.onDestinationSelected,
    required this.onSearch,
    required this.onThemeToggle,
    required this.onProfile,
  });

  @override
  State<_Masthead> createState() => _MastheadState();
}

class _MastheadState extends State<_Masthead>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _glassMotion;
  AppLifecycleState _lifecycle = AppLifecycleState.resumed;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lifecycle =
        WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed;
    _glassMotion = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncMotion();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycle = state;
    _syncMotion();
  }

  void _syncMotion() {
    final disable = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final tickerEnabled = TickerMode.valuesOf(context).enabled;
    final enabled = mounted &&
        !disable &&
        tickerEnabled &&
        _lifecycle == AppLifecycleState.resumed;
    if (enabled && !_glassMotion.isAnimating) {
      _glassMotion.repeat();
    } else if (!enabled && _glassMotion.isAnimating) {
      _glassMotion.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _glassMotion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return Container(
      height: 72,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? [
                  colors.paper.withValues(alpha: 0.96),
                  colors.bgCard.withValues(alpha: 0.98),
                ]
              : [
                  colors.paper.withValues(alpha: 0.98),
                  colors.sky.withValues(alpha: 0.06),
                  colors.sakura.withValues(alpha: 0.05),
                ],
        ),
        border: Border(
          bottom: BorderSide(
            color: colors.divider.withValues(alpha: 0.72),
          ),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 920;
          final horizontal = constraints.maxWidth >= 1440 ? 56.0 : 24.0;

          return Padding(
            padding: EdgeInsets.symmetric(horizontal: horizontal),
            child: Row(
              children: [
                const _Brand(),
                const Spacer(),
                if (compact)
                  AnimatedBuilder(
                    animation: _glassMotion,
                    builder: (context, _) => _CompactNavigation(
                      activeDestination: widget.activeDestination,
                      onSelected: widget.onDestinationSelected,
                      motionProgress: _glassMotion.value,
                    ),
                  )
                else
                  AnimatedBuilder(
                    animation: _glassMotion,
                    builder: (context, _) => _GlassNavigationRail(
                      activeDestination: widget.activeDestination,
                      onSelected: widget.onDestinationSelected,
                      motionProgress: _glassMotion.value,
                      disableAnimations: disableAnimations,
                    ),
                  ),
                const Spacer(),
                AnimatedBuilder(
                  animation: _glassMotion,
                  builder: (context, _) => LiquidGlassSurface(
                    key: const ValueKey('vira-tools-glass'),
                    motionProgress: _glassMotion.value,
                    phase: 0.34,
                    borderRadius: BorderRadius.circular(24),
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _MastheadTool(
                          id: 'search',
                          tooltip: '搜索',
                          icon: Icons.search_rounded,
                          onTap: widget.onSearch,
                        ),
                        const SizedBox(width: 2),
                        _MastheadTool(
                          id: 'theme',
                          tooltip: '切换主题',
                          icon: dark
                              ? Icons.light_mode_outlined
                              : Icons.dark_mode_outlined,
                          onTap: widget.onThemeToggle,
                        ),
                        const SizedBox(width: 2),
                        _MastheadTool(
                          id: 'profile',
                          tooltip: '个人与设置',
                          icon: Icons.person_outline_rounded,
                          onTap: widget.onProfile,
                          accent: true,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _GlassNavigationRail extends StatelessWidget {
  const _GlassNavigationRail({
    required this.activeDestination,
    required this.onSelected,
    required this.motionProgress,
    required this.disableAnimations,
  });

  final ViraDestination? activeDestination;
  final ValueChanged<ViraDestination> onSelected;
  final double motionProgress;
  final bool disableAnimations;

  @override
  Widget build(BuildContext context) {
    final activeIndex = activeDestination == null
        ? -1
        : ViraDestination.values.indexOf(activeDestination!);

    return LiquidGlassSurface(
      key: const ValueKey('vira-navigation-glass'),
      motionProgress: motionProgress,
      borderRadius: BorderRadius.circular(26),
      padding: const EdgeInsets.all(5),
      child: SizedBox(
        width: 340,
        height: 42,
        child: Stack(
          children: [
            if (activeIndex >= 0)
              AnimatedPositioned(
                key: const ValueKey('vira-nav-lens'),
                duration: disableAnimations
                    ? Duration.zero
                    : const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                left: activeIndex * 68,
                top: 0,
                width: 68,
                height: 42,
                child: KeyedSubtree(
                  key: ValueKey(
                    'vira-nav-indicator-${activeDestination!.name}',
                  ),
                  child: KeyedSubtree(
                    key: ValueKey(
                      'vira-nav-lens-${activeDestination!.name}',
                    ),
                    child: const _SelectedGlassLens(),
                  ),
                ),
              ),
            Row(
              children: [
                for (final destination in ViraDestination.values)
                  _NavigationItem(
                    destination: destination,
                    selected: destination == activeDestination,
                    onTap: () => onSelected(destination),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectedGlassLens extends StatelessWidget {
  const _SelectedGlassLens();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: dark
                ? [
                    colors.sky.withValues(alpha: 0.38),
                    Colors.white.withValues(alpha: 0.12),
                  ]
                : [
                    Colors.white.withValues(alpha: 0.94),
                    colors.sky.withValues(alpha: 0.24),
                  ],
          ),
          border: Border.all(
            color: Colors.white.withValues(alpha: dark ? 0.28 : 0.92),
          ),
          boxShadow: [
            BoxShadow(
              color: colors.sky.withValues(alpha: dark ? 0.2 : 0.25),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
            BoxShadow(
              color: Colors.white.withValues(alpha: dark ? 0.04 : 0.6),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Semantics(
      header: true,
      label: '薇拉，私人动画放映室',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.sky,
              borderRadius: BorderRadius.circular(9),
              boxShadow: [
                BoxShadow(
                  color: colors.sky.withValues(alpha: 0.18),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: const Text(
              '薇',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '薇拉',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: colors.textPrimary,
                      letterSpacing: 0.5,
                    ),
              ),
              Text(
                '私人动画放映室',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colors.textMuted,
                      fontWeight: FontWeight.w400,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NavigationItem extends StatefulWidget {
  final ViraDestination destination;
  final bool selected;
  final VoidCallback onTap;

  const _NavigationItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_NavigationItem> createState() => _NavigationItemState();
}

class _NavigationItemState extends State<_NavigationItem> {
  var _hovered = false;
  var _focused = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Semantics(
      button: true,
      selected: widget.selected,
      label: widget.destination.label,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: widget.onTap,
            onFocusChange: (value) => setState(() => _focused = value),
            hoverColor: Colors.transparent,
            focusColor: Colors.transparent,
            splashColor: colors.sky.withValues(alpha: 0.1),
            highlightColor: colors.sky.withValues(alpha: 0.08),
            child: SizedBox(
              width: 68,
              height: 42,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (_hovered && !widget.selected)
                    Positioned.fill(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        margin: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: colors.sky.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  if (_focused)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Container(
                          key: ValueKey(
                            'vira-nav-focus-${widget.destination.name}',
                          ),
                          margin: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(17),
                            border: Border.all(
                              color: colors.sky,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 160),
                    style: Theme.of(context).textTheme.labelLarge!.copyWith(
                          color: widget.selected
                              ? colors.textPrimary
                              : _hovered
                                  ? colors.sky
                                  : colors.textSecondary,
                          fontWeight: widget.selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                    child: Text(widget.destination.label),
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

class _CompactNavigation extends StatelessWidget {
  final ViraDestination? activeDestination;
  final ValueChanged<ViraDestination> onSelected;
  final double motionProgress;

  const _CompactNavigation({
    required this.activeDestination,
    required this.onSelected,
    required this.motionProgress,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<ViraDestination>(
      tooltip: '切换页面',
      onSelected: onSelected,
      itemBuilder: (context) => [
        for (final destination in ViraDestination.values)
          PopupMenuItem(
            value: destination,
            child: Text(destination.label),
          ),
      ],
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: LiquidGlassSurface(
          key: const ValueKey('vira-compact-navigation-glass'),
          motionProgress: motionProgress,
          borderRadius: BorderRadius.circular(22),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
          child: Row(
            children: [
              Text(
                activeDestination?.label ?? '页面',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(width: 4),
              const Icon(Icons.expand_more_rounded, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _MastheadTool extends StatefulWidget {
  final String id;
  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;
  final bool accent;

  const _MastheadTool({
    required this.id,
    required this.tooltip,
    required this.icon,
    required this.onTap,
    this.accent = false,
  });

  @override
  State<_MastheadTool> createState() => _MastheadToolState();
}

class _MastheadToolState extends State<_MastheadTool> {
  var _hovered = false;
  var _focused = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Tooltip(
      message: widget.tooltip,
      child: Semantics(
        button: true,
        label: widget.tooltip,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: BorderRadius.circular(19),
              onTap: widget.onTap,
              onFocusChange: (value) => setState(() => _focused = value),
              hoverColor: Colors.transparent,
              focusColor: Colors.transparent,
              splashColor: colors.sky.withValues(alpha: 0.12),
              highlightColor: colors.sky.withValues(alpha: 0.09),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: widget.accent
                      ? colors.sky.withValues(alpha: _hovered ? 0.95 : 0.86)
                      : _hovered
                          ? colors.sky.withValues(alpha: 0.1)
                          : Colors.transparent,
                  border: Border.all(
                    color: _focused
                        ? colors.sky
                        : widget.accent
                            ? Colors.white.withValues(alpha: 0.58)
                            : _hovered
                                ? colors.sky.withValues(alpha: 0.38)
                                : Colors.transparent,
                    width: _focused ? 1.5 : 1,
                  ),
                  borderRadius: BorderRadius.circular(19),
                  boxShadow: widget.accent
                      ? [
                          BoxShadow(
                            color: colors.sky.withValues(alpha: 0.24),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (_focused)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: SizedBox(
                            key: ValueKey('vira-tool-focus-${widget.id}'),
                          ),
                        ),
                      ),
                    Icon(
                      widget.icon,
                      size: 19,
                      color: widget.accent
                          ? Colors.white
                          : _hovered || _focused
                              ? colors.sky
                              : colors.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
