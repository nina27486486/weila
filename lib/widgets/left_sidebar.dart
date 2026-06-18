import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import '../theme/app_theme.dart';

class LeftSidebar extends StatefulWidget {
  final int selectedIndex;
  final ValueChanged<int> onIndexChanged;

  const LeftSidebar({
    super.key,
    required this.selectedIndex,
    required this.onIndexChanged,
  });

  @override
  State<LeftSidebar> createState() => _LeftSidebarState();
}

class _LeftSidebarState extends State<LeftSidebar> with SingleTickerProviderStateMixin {
  int _hoveredIndex = -1;
  late final AnimationController _logoController;
  late final Animation<double> _logoRotation;

  @override
  void initState() {
    super.initState();
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    _logoRotation = Tween<double>(begin: 0, end: 1).animate(_logoController);
  }

  @override
  void dispose() {
    _logoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      color: AppTheme.bgSidebar,
      child: Column(
        children: [
          // Logo（带微旋转光效）
          Container(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
            child: Row(
              children: [
                AnimatedBuilder(
                  animation: _logoRotation,
                  builder: (context, child) {
                    return Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        gradient: SweepGradient(
                          startAngle: 0,
                          endAngle: 6.28,
                          transform: GradientRotation(_logoRotation.value * 6.28),
                          colors: const [
                            AppTheme.primaryBlue,
                            AppTheme.accentBlue,
                            AppTheme.primaryBlue,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: Text(
                          '薇',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            shadows: [Shadow(blurRadius: 4, color: Colors.black26)],
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 10),
                const Text(
                  '薇拉',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          
          // 主导航
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _buildSectionTitle('发现'),
                _buildNavItem(0, Icons.home_outlined, Icons.home, '首页'),
                _buildNavItem(1, Icons.video_library_outlined, Icons.video_library, '番剧'),
                _buildNavItem(2, Icons.movie_outlined, Icons.movie, '剧场版'),
                _buildNavItem(3, Icons.calendar_month_outlined, Icons.calendar_month, '追番日历'),
                _buildNavItem(4, Icons.leaderboard_outlined, Icons.leaderboard, '排行榜'),
                _buildNavItem(5, Icons.category_outlined, Icons.category, '分类浏览'),
                
                const SizedBox(height: 16),
                _buildSectionTitle('我的'),
                _buildNavItem(6, Icons.bookmark_outline, Icons.bookmark, '追番列表'),
                _buildNavItem(7, Icons.history_outlined, Icons.history, '观看历史'),
                _buildNavItem(8, Icons.download_outlined, Icons.download, '离线缓存'),
                _buildNavItem(9, Icons.favorite_outline, Icons.favorite, '收藏夹'),
                _buildNavItem(10, Icons.watch_later_outlined, Icons.watch_later, '稍后再看'),
                _buildNavItem(11, Icons.person_outline, Icons.person, '个人中心'),
              ],
            ),
          ),
          
          // 底部设置
          const Divider(height: 1),
          _buildNavItem(12, Icons.settings_outlined, Icons.settings, '设置'),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Text(
        title,
        style: const TextStyle(
          color: AppTheme.textMuted,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, IconData activeIcon, String label) {
    final isSelected = widget.selectedIndex == index;
    final isHovered = _hoveredIndex == index;

    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredIndex = index),
      onExit: (_) => setState(() => _hoveredIndex = -1),
      child: GestureDetector(
        onTap: () {
          widget.onIndexChanged(index);
          _navigateToPage(index);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.primaryBlue.withValues(alpha: 0.15)
                : isHovered
                    ? AppTheme.bgHover.withValues(alpha: 0.5)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border(
              left: BorderSide(
                color: isSelected ? AppTheme.primaryBlue : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Row(
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  isSelected ? activeIcon : icon,
                  key: ValueKey('$index-$isSelected'),
                  size: 20,
                  color: isSelected ? AppTheme.primaryBlue : AppTheme.textSecondary,
                ),
              ),
              const SizedBox(width: 12),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  color: isSelected ? AppTheme.primaryBlue : AppTheme.textSecondary,
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
                child: Text(label),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToPage(int index) {
    switch (index) {
      case 0:
        Modular.to.navigate('/');
        break;
      case 1:
        Modular.to.navigate('/anime-list');
        break;
      case 2:
        Modular.to.navigate('/anime-list?type=movie');
        break;
      case 3:
        Modular.to.navigate('/calendar');
        break;
      case 4:
        Modular.to.navigate('/ranking');
        break;
      case 5:
        Modular.to.navigate('/category');
        break;
      case 6:
        Modular.to.navigate('/track');
        break;
      case 7:
        Modular.to.navigate('/history');
        break;
      case 8:
        Modular.to.navigate('/download');
        break;
      case 9:
        Modular.to.navigate('/collect');
        break;
      case 12:
        Modular.to.navigate('/settings');
        break;
    }
  }
}
