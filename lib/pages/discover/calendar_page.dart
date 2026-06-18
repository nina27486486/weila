import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import '../../theme/app_theme.dart';
import '../../services/plugin/plugin_service.dart';
import '../../utils/logger.dart';
import '../../widgets/cover_image.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  final PluginService _pluginService = PluginService();

  int _selectedDay = DateTime.now().weekday - 1; // 0=Monday
  bool _isLoading = true;
  // 按星期几分组的数据：index 0=周一, 6=周日
  List<List<Map<String, dynamic>>> _weekData = List.generate(7, (_) => []);
  String? _error;

  static const List<String> _weekDays = [
    '星期一',
    '星期二',
    '星期三',
    '星期四',
    '星期五',
    '星期六',
    '星期日',
  ];

  static const List<IconData> _weekDayIcons = [
    Icons.looks_one,
    Icons.looks_two,
    Icons.looks_3,
    Icons.looks_4,
    Icons.looks_5,
    Icons.looks_6,
    Icons.filter_7,
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // 加载3页数据（约60条），确保每天都有足够内容
      final allItems = <Map<String, dynamic>>[];
      for (int pg = 1; pg <= 3; pg++) {
        final data = await _pluginService.getCmsLatest(
          pluginApi: 'cms_yinhua',
          page: pg,
        ).timeout(const Duration(seconds: 10), onTimeout: () => <Map<String, dynamic>>[]);
        allItems.addAll(data);
        if (data.length < 15) break; // 最后一页不足15条，不再请求
      }

      // 如果樱花没数据，试非凡
      if (allItems.isEmpty) {
        for (int pg = 1; pg <= 3; pg++) {
          final data = await _pluginService.getCmsLatest(
            pluginApi: 'cms_ffzy',
            page: pg,
          ).timeout(const Duration(seconds: 10), onTimeout: () => <Map<String, dynamic>>[]);
          allItems.addAll(data);
          if (data.length < 15) break;
        }
      }

      // 按 vod_time 的星期几分组
      final grouped = List.generate(7, (_) => <Map<String, dynamic>>[]);
      for (final item in allItems) {
        final timeStr = item['vod_time'] as String? ?? '';
        final dayIndex = _parseWeekday(timeStr);
        if (dayIndex >= 0 && dayIndex < 7) {
          grouped[dayIndex].add(item);
        }
      }

      // 没被分到任何组的数据，放到今天
      // （有些条目可能没有 vod_time）
      final today = DateTime.now().weekday - 1;

      if (mounted) {
        setState(() {
          _weekData = grouped;
          _isLoading = false;
          // 如果选中那天没数据，检查是否全部为空
          final totalItems = grouped.fold<int>(0, (sum, list) => sum + list.length);
          if (totalItems == 0) {
            _error = '暂无数据，请检查网络连接';
          }
        });
      }
    } catch (e) {
      Log.e('Calendar', '加载失败', e);
      if (mounted) {
        setState(() {
          _error = '加载失败: $e';
          _isLoading = false;
        });
      }
    }
  }

  /// 从 "2026-06-13 20:36:04" 格式解析星期几（0=周一, 6=周日）
  int _parseWeekday(String timeStr) {
    try {
      if (timeStr.isEmpty) return -1;
      final dt = DateTime.parse(timeStr);
      return dt.weekday - 1; // DateTime.weekday: 1=Mon, 7=Sun → 0-6
    } catch (_) {
      return -1;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        backgroundColor: AppTheme.bgDark,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
          onPressed: () => Modular.to.navigate('/'),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.calendar_month,
                color: AppTheme.primaryBlue,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              '追番日历',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.textSecondary),
            onPressed: _loadData,
            tooltip: '刷新',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // ── 星期标签栏 ──
          _buildWeekdayTabs(),

          const Divider(color: AppTheme.divider, height: 1, thickness: 1),

          // ── 当前选中日期的番剧列表 ──
          Expanded(
            child: _buildAnimeGrid(),
          ),
        ],
      ),
    );
  }

  /// 星期标签栏
  Widget _buildWeekdayTabs() {
    return Container(
      color: AppTheme.bgCard,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: List.generate(7, (index) {
          final isSelected = _selectedDay == index;
          final isToday = index == DateTime.now().weekday - 1;

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () => setState(() => _selectedDay = index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutCubic,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.primaryBlue
                          : isToday
                              ? AppTheme.primaryBlue.withValues(alpha: 0.1)
                              : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected
                            ? AppTheme.primaryBlue
                            : isToday
                                ? AppTheme.primaryBlue.withValues(alpha: 0.4)
                                : AppTheme.divider,
                        width: isSelected ? 0 : 1,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _weekDayIcons[index],
                          size: 16,
                          color: isSelected
                              ? Colors.white
                              : isToday
                                  ? AppTheme.primaryBlue
                                  : AppTheme.textMuted,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _weekDays[index],
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected || isToday
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: isSelected
                                ? Colors.white
                                : isToday
                                    ? AppTheme.primaryBlue
                                    : AppTheme.textSecondary,
                          ),
                        ),
                        if (_weekData[index].isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              '${_weekData[index].length}',
                              style: TextStyle(
                                fontSize: 10,
                                color: isSelected
                                    ? Colors.white70
                                    : AppTheme.textMuted,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  /// 番剧网格
  Widget _buildAnimeGrid() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppTheme.primaryBlue, strokeWidth: 2),
            SizedBox(height: 16),
            Text('加载中...', style: TextStyle(color: AppTheme.textMuted)),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppTheme.scoreOrange),
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: AppTheme.textSecondary)),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (_weekData[_selectedDay].isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.calendar_today_outlined, size: 56, color: AppTheme.textMuted),
            const SizedBox(height: 12),
            Text('${_weekDays[_selectedDay]}暂无更新', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 15)),
            const SizedBox(height: 4),
            const Text('试试其他日期吧', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppTheme.primaryBlue,
      onRefresh: _loadData,
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 420,
          mainAxisExtent: 110,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
        ),
        itemCount: _weekData[_selectedDay].length,
        itemBuilder: (context, index) {
          final item = _weekData[_selectedDay][index];
          return _CalendarAnimeCard(
            item: item,
            index: index,
            onTap: () {
              Modular.to.pushNamed(
                '/detail?url=${Uri.encodeComponent(item['url'] ?? '')}'
                '&name=${Uri.encodeComponent(item['name'] ?? '')}',
              );
            },
          );
        },
      ),
    );
  }
}

/// 日历页专用紧凑动漫卡片
class _CalendarAnimeCard extends StatefulWidget {
  final Map<String, dynamic> item;
  final int index;
  final VoidCallback onTap;

  const _CalendarAnimeCard({
    required this.item,
    required this.index,
    required this.onTap,
  });

  @override
  State<_CalendarAnimeCard> createState() => _CalendarAnimeCardState();
}

class _CalendarAnimeCardState extends State<_CalendarAnimeCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final name = widget.item['name'] ?? '';
    final cover = widget.item['cover'] as String?;
    final status = widget.item['status'] as String? ?? '';
    final score = widget.item['score'] as double?;
    final genres = (widget.item['genres'] as List?)?.cast<String>() ?? [];

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 350 + widget.index * 40),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 12 * (1 - value)),
            child: child,
          ),
        );
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              color: _hovering ? AppTheme.bgHover : AppTheme.bgCard,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _hovering
                    ? AppTheme.primaryBlue.withValues(alpha: 0.3)
                    : AppTheme.divider,
              ),
            ),
            child: Row(
              children: [
                // ── 封面 ──
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(10),
                    bottomLeft: Radius.circular(10),
                  ),
                  child: Container(
                    width: 80,
                    height: double.infinity,
                    color: AppTheme.bgSurface,
                    child: CoverImage(url: cover, fit: BoxFit.cover),
                  ),
                ),

                // ── 信息区 ──
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // 标题
                        Text(
                          name,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),

                        // 状态标签 + 评分
                        Row(
                          children: [
                            if (status.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.tagHighlight.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  status,
                                  style: const TextStyle(
                                    color: AppTheme.accentBlue,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            if (score != null && score > 0) ...[
                              const SizedBox(width: 6),
                              const Icon(
                                Icons.star_rounded,
                                size: 13,
                                color: AppTheme.scoreOrange,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                score.toStringAsFixed(1),
                                style: const TextStyle(
                                  color: AppTheme.scoreOrange,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 6),

                        // 类型标签
                        if (genres.isNotEmpty)
                          Wrap(
                            spacing: 4,
                            children: genres.take(3).map((g) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.tagBg,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: Text(
                                  g,
                                  style: const TextStyle(
                                    color: AppTheme.textMuted,
                                    fontSize: 10,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                      ],
                    ),
                  ),
                ),

                // 右侧箭头
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: _hovering
                        ? AppTheme.primaryBlue
                        : AppTheme.textMuted.withValues(alpha: 0.3),
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
