import 'package:flutter/material.dart';

import '../../theme/vira_colors.dart';
import '../../widgets/cover_image.dart';
import '../../widgets/editorial_section_header.dart';
import '../../widgets/vira_state_view.dart';

class BroadcastCalendarView extends StatelessWidget {
  static const weekDays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

  final List<List<Map<String, dynamic>>> weekData;
  final int selectedDay;
  final int todayIndex;
  final bool isLoading;
  final String? errorMessage;
  final ValueChanged<int> onDaySelected;
  final ValueChanged<Map<String, dynamic>> onOpenAnime;
  final VoidCallback onRetry;
  final VoidCallback onRefresh;

  const BroadcastCalendarView({
    super.key,
    required this.weekData,
    required this.selectedDay,
    required this.todayIndex,
    required this.onDaySelected,
    required this.onOpenAnime,
    required this.onRetry,
    required this.onRefresh,
    this.isLoading = false,
    this.errorMessage,
  });

  @override
  Widget build(BuildContext context) {
    final safeDay = selectedDay.clamp(0, 6);
    final selectedItems = safeDay < weekData.length
        ? weekData[safeDay]
        : const <Map<String, dynamic>>[];
    final isToday = safeDay == todayIndex;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 34),
            child: _CalendarIntroduction(
              todayCount: todayIndex < weekData.length
                  ? weekData[todayIndex].length
                  : 0,
              onRefresh: onRefresh,
              refreshing: isLoading,
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 24),
            child: _WeekStrip(
              key: const ValueKey('calendar-week-strip'),
              weekData: weekData,
              selectedDay: safeDay,
              todayIndex: todayIndex,
              onSelected: onDaySelected,
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 34, bottom: 16),
            child: EditorialSectionHeader(
              chapter: isToday ? '今日页签' : '本周页签',
              title: isToday ? '今天的放送' : '${weekDays[safeDay]}的放送',
              subtitle: selectedItems.isEmpty
                  ? '今天留白，也可以回看喜欢的故事'
                  : '共 ${selectedItems.length} 部作品等待更新',
            ),
          ),
        ),
        if (isLoading && weekData.every((items) => items.isEmpty))
          const SliverFillRemaining(
            hasScrollBody: false,
            child: ViraStateView.loading(
              title: '正在排版本周节目单',
              message: '放送日期和作品信息正在汇合。',
            ),
          )
        else if (errorMessage != null &&
            weekData.every((items) => items.isEmpty))
          SliverFillRemaining(
            hasScrollBody: false,
            child: ViraStateView.error(
              title: '放送表暂时缺席',
              message: errorMessage!,
              onRetry: onRetry,
            ),
          )
        else if (selectedItems.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: ViraStateView.empty(
              title: '${weekDays[safeDay]}没有新放送',
              message: '换一天看看，或者回到资料库重温旧故事。',
            ),
          )
        else
          SliverPadding(
            key: const ValueKey('calendar-day-grid'),
            padding: const EdgeInsets.only(bottom: 36),
            sliver: SliverGrid.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 430,
                mainAxisExtent: 132,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
              ),
              itemCount: selectedItems.length,
              itemBuilder: (context, index) {
                final item = selectedItems[index];
                return _ScheduleCard(
                  index: index,
                  item: item,
                  isToday: isToday,
                  onTap: () => onOpenAnime(item),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _CalendarIntroduction extends StatelessWidget {
  final int todayCount;
  final VoidCallback onRefresh;
  final bool refreshing;

  const _CalendarIntroduction({
    required this.todayCount,
    required this.onRefresh,
    required this.refreshing,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final now = DateTime.now();
    const months = [
      '一月',
      '二月',
      '三月',
      '四月',
      '五月',
      '六月',
      '七月',
      '八月',
      '九月',
      '十月',
      '十一月',
      '十二月',
    ];

    return Container(
      padding: const EdgeInsets.only(bottom: 28),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.divider)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            width: 88,
            height: 108,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.sakuraLight,
              border: Border.all(color: colors.sakura.withValues(alpha: 0.48)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  months[now.month - 1],
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colors.danger,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                Text(
                  now.day.toString().padLeft(2, '0'),
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        color: colors.textPrimary,
                        fontSize: 31,
                        height: 0.95,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '每周放送手账',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colors.sky,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.4,
                      ),
                ),
                const SizedBox(height: 10),
                Text(
                  '追番日历',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        fontSize: 40,
                      ),
                ),
                const SizedBox(height: 7),
                Text(
                  todayCount == 0
                      ? '今天没有新放送，适合慢慢补完旧故事。'
                      : '今天有 $todayCount 部作品更新，已经替你排好顺序。',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          Tooltip(
            message: '刷新日历',
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: OutlinedButton.icon(
                onPressed: refreshing ? null : onRefresh,
                icon: refreshing
                    ? const SizedBox(
                        width: 15,
                        height: 15,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded, size: 17),
                label: const Text('刷新节目单'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekStrip extends StatelessWidget {
  final List<List<Map<String, dynamic>>> weekData;
  final int selectedDay;
  final int todayIndex;
  final ValueChanged<int> onSelected;

  const _WeekStrip({
    super.key,
    required this.weekData,
    required this.selectedDay,
    required this.todayIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.colors.paper,
        border: Border(
          top: BorderSide(color: context.colors.divider),
          bottom: BorderSide(color: context.colors.divider),
        ),
      ),
      child: Row(
        children: [
          for (var index = 0; index < 7; index++)
            Expanded(
              child: _DayIndex(
                label: BroadcastCalendarView.weekDays[index],
                count: index < weekData.length ? weekData[index].length : 0,
                selected: index == selectedDay,
                today: index == todayIndex,
                showDivider: index != 6,
                onTap: () => onSelected(index),
              ),
            ),
        ],
      ),
    );
  }
}

class _DayIndex extends StatefulWidget {
  final String label;
  final int count;
  final bool selected;
  final bool today;
  final bool showDivider;
  final VoidCallback onTap;

  const _DayIndex({
    required this.label,
    required this.count,
    required this.selected,
    required this.today,
    required this.showDivider,
    required this.onTap,
  });

  @override
  State<_DayIndex> createState() => _DayIndexState();
}

class _DayIndexState extends State<_DayIndex> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Semantics(
      button: true,
      selected: widget.selected,
      label: '${widget.label}，${widget.count}部作品',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            height: 78,
            decoration: BoxDecoration(
              color: widget.selected
                  ? colors.skyLight
                  : _hovered
                      ? colors.bgHover
                      : Colors.transparent,
              border: Border(
                right: widget.showDivider
                    ? BorderSide(color: colors.divider)
                    : BorderSide.none,
                bottom: BorderSide(
                  color: widget.selected ? colors.sky : Colors.transparent,
                  width: 2,
                ),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.label,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: widget.selected
                                ? colors.sky
                                : colors.textPrimary,
                          ),
                    ),
                    if (widget.today) ...[
                      const SizedBox(width: 5),
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: colors.sakura,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  widget.count == 0 ? '留白' : '${widget.count} 部',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: widget.selected ? colors.sky : colors.textMuted,
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

class _ScheduleCard extends StatefulWidget {
  final int index;
  final Map<String, dynamic> item;
  final bool isToday;
  final VoidCallback onTap;

  const _ScheduleCard({
    required this.index,
    required this.item,
    required this.isToday,
    required this.onTap,
  });

  @override
  State<_ScheduleCard> createState() => _ScheduleCardState();
}

class _ScheduleCardState extends State<_ScheduleCard> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final name = widget.item['name']?.toString() ?? '未命名作品';
    final status = widget.item['status']?.toString() ?? '等待更新';
    final genres = _genresOf(widget.item);
    final score = _scoreOf(widget.item);

    return Semantics(
      button: true,
      label: '查看$name',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 170),
            transform: Matrix4.translationValues(0, _hovered ? -2 : 0, 0),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: _hovered ? colors.bgHover : colors.paper,
              border: Border.all(
                color: _hovered
                    ? colors.sky.withValues(alpha: 0.55)
                    : colors.divider,
              ),
              boxShadow: _hovered
                  ? [
                      BoxShadow(
                        color: colors.textPrimary.withValues(alpha: 0.07),
                        blurRadius: 16,
                        offset: const Offset(0, 7),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 92,
                  height: double.infinity,
                  child: CoverImage(
                    url: widget.item['cover']?.toString(),
                    fit: BoxFit.cover,
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 10, 11),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            Text(
                              '场次 ${(widget.index + 1).toString().padLeft(2, '0')}',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color: widget.isToday
                                        ? colors.danger
                                        : colors.sky,
                                    letterSpacing: 0.8,
                                  ),
                            ),
                            const Spacer(),
                            if (score != null) ...[
                              Icon(
                                Icons.star_rounded,
                                size: 13,
                                color: colors.warning,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                score.toStringAsFixed(1),
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 5),
                        Text(
                          genres.isEmpty
                              ? status
                              : '$status · ${genres.take(2).join(' / ')}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    size: 16,
                    color: _hovered ? colors.sky : colors.textMuted,
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

List<String> _genresOf(Map<String, dynamic> item) {
  final raw = item['genres'];
  if (raw is! List) return const [];
  return raw.map((entry) => entry.toString()).toList(growable: false);
}

double? _scoreOf(Map<String, dynamic> item) {
  final raw = item['score'];
  return raw is num ? raw.toDouble() : double.tryParse(raw?.toString() ?? '');
}
