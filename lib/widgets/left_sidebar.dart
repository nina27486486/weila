import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

import '../theme/app_theme.dart';
import '../theme/vira_colors.dart';
import '../utils/animations.dart';

class LeftSidebar extends StatefulWidget {
  const LeftSidebar({
    super.key,
    required this.selectedIndex,
    required this.onIndexChanged,
  });

  final int selectedIndex;
  final ValueChanged<int> onIndexChanged;

  @override
  State<LeftSidebar> createState() => _LeftSidebarState();
}

class _LeftSidebarState extends State<LeftSidebar> {
  int _hoveredIndex = -1;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 204,
      decoration: BoxDecoration(
        color: context.colors.bgSidebar,
        border: Border(right: BorderSide(color: context.colors.divider)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 20, 14, 18),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue,
                    borderRadius: BorderRadius.circular(9),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.16)),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    '薇',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('薇拉', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 1),
                    Text(
                      '私人动漫资料库',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: context.colors.textMuted,
                            fontWeight: FontWeight.w400,
                          ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Divider(height: 1, color: context.colors.divider),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 12),
              children: [
                _buildSectionTitle('发现'),
                _buildNavItem(0, Icons.home_outlined, Icons.home_rounded, '首页'),
                _buildNavItem(1, Icons.video_library_outlined,
                    Icons.video_library_rounded, '番剧'),
                _buildNavItem(
                    2, Icons.movie_outlined, Icons.movie_rounded, '剧场版'),
                _buildNavItem(3, Icons.calendar_month_outlined,
                    Icons.calendar_month_rounded, '追番日历'),
                _buildNavItem(4, Icons.leaderboard_outlined,
                    Icons.leaderboard_rounded, '排行榜'),
                _buildNavItem(
                    5, Icons.category_outlined, Icons.category_rounded, '分类浏览'),
                const SizedBox(height: 18),
                _buildSectionTitle('我的'),
                _buildNavItem(6, Icons.bookmark_outline_rounded,
                    Icons.bookmark_rounded, '追番列表'),
                _buildNavItem(7, Icons.history_rounded,
                    Icons.history_toggle_off_rounded, '观看历史'),
                _buildNavItem(
                    8, Icons.download_outlined, Icons.download_rounded, '离线缓存'),
                _buildNavItem(9, Icons.favorite_outline_rounded,
                    Icons.favorite_rounded, '收藏夹'),
              ],
            ),
          ),
          Divider(height: 1, color: context.colors.divider),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: _buildNavItem(
                12, Icons.settings_outlined, Icons.settings_rounded, '设置'),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 4, 16, 7),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: context.colors.textMuted,
              letterSpacing: 1.2,
            ),
      ),
    );
  }

  Widget _buildNavItem(
      int index, IconData icon, IconData activeIcon, String label) {
    final selected = widget.selectedIndex == index;
    final hovered = _hoveredIndex == index;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hoveredIndex = index),
      onExit: (_) => setState(() => _hoveredIndex = -1),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 1),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(7),
            onTap: () {
              widget.onIndexChanged(index);
              _navigateToPage(index);
            },
            child: AnimatedContainer(
              duration: AppAnimations.fast,
              curve: AppAnimations.easeOut,
              height: 39,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: selected
                    ? AppTheme.primaryBlue.withValues(alpha: 0.11)
                    : hovered
                        ? context.colors.bgHover.withValues(alpha: 0.55)
                        : Colors.transparent,
                borderRadius: BorderRadius.circular(7),
                border: Border(
                  left: BorderSide(
                    color: selected ? AppTheme.primaryBlue : Colors.transparent,
                    width: 2,
                  ),
                ),
              ),
              child: Row(
                children: [
                  AnimatedSwitcher(
                    duration: AppAnimations.fast,
                    child: Icon(
                      selected ? activeIcon : icon,
                      key: ValueKey('$index-$selected'),
                      size: 19,
                      color: selected
                          ? AppTheme.accentBlue
                          : context.colors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 11),
                  AnimatedDefaultTextStyle(
                    duration: AppAnimations.fast,
                    style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                          color: selected
                              ? context.colors.textPrimary
                              : context.colors.textSecondary,
                          fontWeight:
                              selected ? FontWeight.w600 : FontWeight.w400,
                        ),
                    child: Text(label),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _navigateToPage(int index) {
    switch (index) {
      case 0:
        Modular.to.navigate('/');
        return;
      case 1:
        Modular.to.navigate('/anime-list');
        return;
      case 2:
        Modular.to.navigate('/anime-list?type=movie');
        return;
      case 3:
        Modular.to.navigate('/calendar');
        return;
      case 4:
        Modular.to.navigate('/ranking');
        return;
      case 5:
        Modular.to.navigate('/category');
        return;
      case 6:
        Modular.to.navigate('/track');
        return;
      case 7:
        Modular.to.navigate('/history');
        return;
      case 8:
        Modular.to.navigate('/download');
        return;
      case 9:
        Modular.to.navigate('/collect');
        return;
      case 12:
        Modular.to.navigate('/settings');
        return;
    }
  }
}
