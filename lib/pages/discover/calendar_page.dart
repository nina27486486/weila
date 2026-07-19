import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

import '../../services/plugin/plugin_service.dart';
import '../../stores/theme_store.dart';
import '../../utils/logger.dart';
import '../../widgets/vira_page_chrome.dart';
import 'broadcast_calendar_view.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  final _pluginService = PluginService();

  int _selectedDay = DateTime.now().weekday - 1;
  bool _isLoading = true;
  List<List<Map<String, dynamic>>> _weekData = List.generate(7, (_) => []);
  String? _error;

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
      final schedule = await _pluginService.getJikanSchedule();
      const dayKeys = [
        'monday',
        'tuesday',
        'wednesday',
        'thursday',
        'friday',
        'saturday',
        'sunday',
      ];
      final grouped =
          List.generate(7, (index) => schedule[dayKeys[index]] ?? []);

      if (mounted && grouped.any((items) => items.isNotEmpty)) {
        setState(() {
          _weekData = grouped;
          _isLoading = false;
        });
        return;
      }
    } catch (error) {
      Log.e('Calendar', 'Jikan 放送表失败，降级到 CMS', error);
    }

    try {
      final allItems = await _loadCmsFallback();
      final grouped = List.generate(7, (_) => <Map<String, dynamic>>[]);

      for (final item in allItems) {
        final dayIndex = _parseWeekday(item['vod_time']?.toString() ?? '');
        if (dayIndex >= 0 && dayIndex < 7) {
          grouped[dayIndex].add(item);
        }
      }

      if (!mounted) return;
      setState(() {
        _weekData = grouped;
        _isLoading = false;
        if (grouped.every((items) => items.isEmpty)) {
          _error = '暂时没有取得本周放送数据，请稍后再试。';
        }
      });
    } catch (error) {
      Log.e('Calendar', 'CMS 放送表加载失败', error);
      if (!mounted) return;
      setState(() {
        _error = '放送表加载失败，请检查网络后再试。';
        _isLoading = false;
      });
    }
  }

  Future<List<Map<String, dynamic>>> _loadCmsFallback() async {
    final allItems = <Map<String, dynamic>>[];

    for (final source in ['cms_yinhua', 'cms_ffzy']) {
      for (var page = 1; page <= 3; page++) {
        final data = await _pluginService
            .getCmsLatest(pluginApi: source, page: page)
            .timeout(
              const Duration(seconds: 10),
              onTimeout: () => <Map<String, dynamic>>[],
            );
        allItems.addAll(data);
        if (data.length < 15) break;
      }
      if (allItems.isNotEmpty) break;
    }

    return allItems;
  }

  int _parseWeekday(String raw) {
    if (raw.isEmpty) return -1;
    try {
      return DateTime.parse(raw).weekday - 1;
    } catch (_) {
      return -1;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ViraPageScaffold(
      activeDestination: ViraDestination.following,
      onDestinationSelected: _openDestination,
      onSearch: () => Modular.to.pushNamed('/search'),
      onThemeToggle: () => Modular.get<ThemeStore>().toggleTheme(),
      onProfile: () => Modular.to.pushNamed('/settings'),
      child: BroadcastCalendarView(
        weekData: _weekData,
        selectedDay: _selectedDay,
        todayIndex: DateTime.now().weekday - 1,
        isLoading: _isLoading,
        errorMessage: _error,
        onDaySelected: (value) => setState(() => _selectedDay = value),
        onOpenAnime: _openDetail,
        onRetry: _loadData,
        onRefresh: _loadData,
      ),
    );
  }

  void _openDestination(ViraDestination destination) {
    final route = switch (destination) {
      ViraDestination.home => '/',
      ViraDestination.discover => '/category',
      ViraDestination.following => '/track',
      ViraDestination.library => '/collect',
      ViraDestination.downloads => '/download',
    };
    if (destination != ViraDestination.following) {
      Modular.to.navigate(route);
    }
  }

  void _openDetail(Map<String, dynamic> item) {
    final url = item['url']?.toString() ?? '';
    final name = item['name']?.toString() ?? '';
    if (url.isEmpty) return;
    Modular.to.pushNamed(
      '/detail?url=${Uri.encodeComponent(url)}'
      '&name=${Uri.encodeComponent(name)}',
    );
  }
}
