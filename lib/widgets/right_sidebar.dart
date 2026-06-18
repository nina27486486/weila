import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// 追番信息
class TrackingAnime {
  final String title;
  final String? coverUrl;
  final String? updateInfo; // 如 "更新至第12集"
  final String? updateTime; // 如 "昨天 18:00"

  const TrackingAnime({
    required this.title,
    this.coverUrl,
    this.updateInfo,
    this.updateTime,
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
      color: AppTheme.bgDark,
      child: Column(
        children: [
          // 正在追番
          _buildSection(
            title: '正在追番',
            icon: Icons.play_circle_outline,
            child: _buildTrackingList(),
          ),
          
          const Divider(height: 1),
          
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
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
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
      return const Center(
        child: Text(
          '还没有追番\n去首页看看有什么新番吧',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
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
            onTap: () {},
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  // 小封面
                  Container(
                    width: 40,
                    height: 54,
                    decoration: BoxDecoration(
                      color: AppTheme.bgCard,
                      borderRadius: BorderRadius.circular(4),
                      image: anime.coverUrl != null
                          ? DecorationImage(
                              image: NetworkImage(anime.coverUrl!),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: anime.coverUrl == null
                        ? const Icon(Icons.movie, size: 16, color: AppTheme.textMuted)
                        : null,
                  ),
                  const SizedBox(width: 10),
                  // 信息
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          anime.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (anime.updateInfo != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: Text(
                              anime.updateInfo!,
                              style: const TextStyle(
                                color: AppTheme.updating,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        if (anime.updateTime != null)
                          Text(
                            anime.updateTime!,
                            style: const TextStyle(
                              color: AppTheme.textMuted,
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
              return GestureDetector(
                onTap: () => setState(() => _selectedDay = index),
                child: Container(
                  margin: const EdgeInsets.only(right: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.primaryBlue : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _weekdays[index],
                    style: TextStyle(
                      color: isSelected ? Colors.white : AppTheme.textSecondary,
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
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
      return const Center(
        child: Text(
          '今天没有更新',
          style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
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
                style: const TextStyle(
                  color: AppTheme.primaryBlue,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      anime.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 12,
                      ),
                    ),
                    if (anime.episode != null)
                      Text(
                        anime.episode!,
                        style: const TextStyle(
                          color: AppTheme.textMuted,
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
