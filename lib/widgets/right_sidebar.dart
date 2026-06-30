import '../theme/vira_colors.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'cover_image.dart';

/// 追番信息
class TrackingAnime {
  final String title;
  final String? coverUrl;
  final String? updateInfo; // 如 "更新至第12集"
  final String? updateTime; // 如 "昨天 18:00"
  final VoidCallback? onTap;

  const TrackingAnime({
    required this.title,
    this.coverUrl,
    this.updateInfo,
    this.updateTime,
    this.onTap,
  });
}

/// 日历番剧
class CalendarAnime {
  final String title;
  final String time; // 如 "10:00"
  final String? episode; // 如 "第12集"

  const CalendarAnime({
    required this.title,
    required this.time,
    this.episode,
  });
}

/// 右侧边栏 - 正在追番 + 追番日历
class RightSidebar extends StatefulWidget {
  final List<TrackingAnime> trackingList;
  final Map<String, List<CalendarAnime>> calendarData;

  const RightSidebar({
    super.key,
    this.trackingList = const [],
    this.calendarData = const {},
  });

  @override
  State<RightSidebar> createState() => _RightSidebarState();
}

class _RightSidebarState extends State<RightSidebar> {
  int _selectedDay = DateTime.now().weekday - 1; // 0=周一
  static const _weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      color: context.colors.bgDark,
      child: Column(
        children: [
          // 正在追番
          _buildSection(
            title: '正在追番',
            icon: Icons.play_circle_outline,
            child: _buildTrackingList(),
          ),

          Divider(height: 1),

          // 追番日历
          _buildSection(
            title: '追番日历',
            icon: Icons.calendar_month_outlined,
            child: _buildCalendar(),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Icon(icon, size: 18, color: AppTheme.primaryBlue),
                SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    color: context.colors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _buildTrackingList() {
    if (widget.trackingList.isEmpty) {
      return Center(
        child: Text(
          '还没有追番\n去首页看看有什么新番吧',
          textAlign: TextAlign.center,
          style: TextStyle(color: context.colors.textMuted, fontSize: 12),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      itemCount: widget.trackingList.length,
      itemBuilder: (context, index) {
        final anime = widget.trackingList[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 4),
          child: InkWell(
            mouseCursor: anime.onTap == null
                ? MouseCursor.defer
                : SystemMouseCursors.click,
            onTap: anime.onTap,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  // 小封面
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      width: 40,
                      height: 54,
                      color: context.colors.bgCard,
                      child: CoverImage(url: anime.coverUrl, fit: BoxFit.cover),
                    ),
                  ),
                  SizedBox(width: 10),
                  // 信息
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          anime.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: context.colors.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (anime.updateInfo != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: Text(
                              anime.updateInfo!,
                              style: TextStyle(
                                color: AppTheme.updating,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        if (anime.updateTime != null)
                          Text(
                            anime.updateTime!,
                            style: TextStyle(
                              color: context.colors.textMuted,
                              fontSize: 10,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCalendar() {
    return Column(
      children: [
        // 星期选择
        SizedBox(
          height: 36,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: 7,
            itemBuilder: (context, index) {
              final isSelected = _selectedDay == index;
              return _CalendarDayButton(
                label: _weekdays[index],
                selected: isSelected,
                onTap: () => setState(() => _selectedDay = index),
              );
            },
          ),
        ),
        SizedBox(height: 8),
        // 当日番剧列表
        Expanded(
          child: _buildDayAnimeList(),
        ),
      ],
    );
  }

  Widget _buildDayAnimeList() {
    final dayKey = _weekdays[_selectedDay];
    final animeList = widget.calendarData[dayKey] ?? [];

    if (animeList.isEmpty) {
      return Center(
        child: Text(
          '今天没有更新',
          style: TextStyle(color: context.colors.textMuted, fontSize: 12),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      itemCount: animeList.length,
      itemBuilder: (context, index) {
        final anime = animeList[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: [
              Text(
                anime.time,
                style: TextStyle(
                  color: AppTheme.primaryBlue,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      anime.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.colors.textPrimary,
                        fontSize: 12,
                      ),
                    ),
                    if (anime.episode != null)
                      Text(
                        anime.episode!,
                        style: TextStyle(
                          color: context.colors.textMuted,
                          fontSize: 10,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CalendarDayButton extends StatefulWidget {
  const _CalendarDayButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_CalendarDayButton> createState() => _CalendarDayButtonState();
}

class _CalendarDayButtonState extends State<_CalendarDayButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.only(right: 4),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: widget.selected
                ? AppTheme.primaryBlue
                : (_hovering ? context.colors.bgHover : Colors.transparent),
            borderRadius: BorderRadius.circular(6),
          ),
          alignment: Alignment.center,
          child: Text(
            widget.label,
            style: TextStyle(
              color:
                  widget.selected ? Colors.white : context.colors.textSecondary,
              fontSize: 12,
              fontWeight: widget.selected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}
