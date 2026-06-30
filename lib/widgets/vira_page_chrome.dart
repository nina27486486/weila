import 'package:flutter/material.dart';

import '../theme/vira_colors.dart';

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

class _Masthead extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      height: 72,
      decoration: BoxDecoration(
        color: colors.paper.withValues(alpha: 0.97),
        border: Border(bottom: BorderSide(color: colors.divider)),
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
                  _CompactNavigation(
                    activeDestination: activeDestination,
                    onSelected: onDestinationSelected,
                  )
                else
                  Row(
                    children: [
                      for (final destination in ViraDestination.values)
                        _NavigationItem(
                          destination: destination,
                          selected: destination == activeDestination,
                          onTap: () => onDestinationSelected(destination),
                        ),
                    ],
                  ),
                const Spacer(),
                _MastheadTool(
                  tooltip: '搜索',
                  icon: Icons.search_rounded,
                  onTap: onSearch,
                ),
                const SizedBox(width: 6),
                _MastheadTool(
                  tooltip: '切换主题',
                  icon: Theme.of(context).brightness == Brightness.dark
                      ? Icons.light_mode_outlined
                      : Icons.dark_mode_outlined,
                  onTap: onThemeToggle,
                ),
                const SizedBox(width: 6),
                _MastheadTool(
                  tooltip: '个人与设置',
                  icon: Icons.person_outline_rounded,
                  onTap: onProfile,
                  accent: true,
                ),
              ],
            ),
          );
        },
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
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: SizedBox(
            width: 68,
            height: 72,
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 160),
                  style: Theme.of(context).textTheme.labelLarge!.copyWith(
                        color: widget.selected
                            ? colors.textPrimary
                            : _hovered
                                ? colors.sky
                                : colors.textSecondary,
                        fontWeight:
                            widget.selected ? FontWeight.w700 : FontWeight.w500,
                      ),
                  child: Text(widget.destination.label),
                ),
                if (widget.selected)
                  Positioned(
                    key: ValueKey(
                      'vira-nav-indicator-${widget.destination.name}',
                    ),
                    bottom: 0,
                    child: Container(
                      width: 22,
                      height: 2,
                      color: colors.sky,
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

class _CompactNavigation extends StatelessWidget {
  final ViraDestination? activeDestination;
  final ValueChanged<ViraDestination> onSelected;

  const _CompactNavigation({
    required this.activeDestination,
    required this.onSelected,
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;
  final bool accent;

  const _MastheadTool({
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
          child: GestureDetector(
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: widget.accent
                    ? colors.sky
                    : _hovered
                        ? colors.bgHover
                        : Colors.transparent,
                border: Border.all(
                  color: widget.accent
                      ? colors.sky
                      : _hovered
                          ? colors.sky.withValues(alpha: 0.42)
                          : colors.divider,
                ),
                borderRadius: BorderRadius.circular(19),
              ),
              child: Icon(
                widget.icon,
                size: 19,
                color: widget.accent
                    ? Colors.white
                    : _hovered
                        ? colors.sky
                        : colors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
