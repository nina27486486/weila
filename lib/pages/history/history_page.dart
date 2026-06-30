import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_modular/flutter_modular.dart';

import '../../stores/history_collect_store.dart';
import '../../stores/theme_store.dart';
import '../../theme/vira_colors.dart';
import '../../widgets/vira_page_chrome.dart';
import '../library/personal_archive_view.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final _store = HistoryCollectStore();

  @override
  void initState() {
    super.initState();
    _store.loadHistory();
  }

  @override
  Widget build(BuildContext context) {
    return ViraPageScaffold(
      activeDestination: ViraDestination.library,
      onDestinationSelected: _openDestination,
      onSearch: () => Modular.to.pushNamed('/search'),
      onThemeToggle: () => Modular.get<ThemeStore>().toggleTheme(),
      onProfile: () => Modular.to.pushNamed('/settings'),
      child: Observer(
        builder: (_) {
          final historyById = {
            for (final item in _store.historyList)
              '${item.animeUrl}|${item.episodeUrl}': item,
          };
          final entries = historyById.entries
              .map(
                (entry) => ArchiveEntry(
                  id: entry.key,
                  title: entry.value.animeName,
                  coverUrl: entry.value.cover,
                  subtitle: entry.value.episodeName,
                  meta: _timeAgo(entry.value.watchedAt),
                  sourceLabel: entry.value.sourcePlugin,
                  progress: entry.value.duration.inMilliseconds > 0
                      ? entry.value.position.inMilliseconds /
                          entry.value.duration.inMilliseconds
                      : 0,
                ),
              )
              .toList(growable: false);

          return PersonalArchiveView(
            title: '观看足迹',
            description: '接住上次停下的位置，也保留每次与故事相遇的时间。',
            mode: ArchiveDisplayMode.timeline,
            entries: entries,
            sections: const [
              ArchiveSection(id: 'collect', label: '收藏夹'),
              ArchiveSection(id: 'history', label: '观看足迹'),
            ],
            selectedSectionId: 'history',
            onSectionSelected: (section) {
              if (section == 'collect') Modular.to.navigate('/collect');
            },
            onOpen: (entry) {
              final item = historyById[entry.id];
              if (item == null) return;
              Modular.to.pushNamed(
                '/player?url=${Uri.encodeComponent(item.episodeUrl)}'
                '&title=${Uri.encodeComponent(item.episodeName)}'
                '&animeUrl=${Uri.encodeComponent(item.animeUrl)}'
                '&ep=${item.episodeUrl.split('/ep/').last}'
                '&source=${Uri.encodeComponent(item.sourcePlugin)}',
              );
            },
            onRemove: (entry) async {
              await historyById[entry.id]?.delete();
              _store.loadHistory();
            },
            onClearAll: () => _confirmClear(context),
          );
        },
      ),
    );
  }

  Future<void> _confirmClear(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('清空观看足迹'),
        content: const Text('所有观看位置都会被移除，确定继续吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('保留'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: context.colors.danger,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('清空'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _store.clearHistory();
    }
  }

  String _timeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes}分钟前';
    if (diff.inDays < 1) return '${diff.inHours}小时前';
    if (diff.inDays < 7) return '${diff.inDays}天前';
    return '${time.month}月${time.day}日';
  }

  void _openDestination(ViraDestination destination) {
    final route = switch (destination) {
      ViraDestination.home => '/',
      ViraDestination.discover => '/category',
      ViraDestination.following => '/track',
      ViraDestination.library => '/collect',
      ViraDestination.downloads => '/download',
    };
    if (destination != ViraDestination.library) {
      Modular.to.navigate(route);
    }
  }
}
