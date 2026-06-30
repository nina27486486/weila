import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_modular/flutter_modular.dart';

import '../../stores/history_collect_store.dart';
import '../../stores/theme_store.dart';
import '../../widgets/vira_page_chrome.dart';
import '../library/personal_archive_view.dart';

class TrackPage extends StatefulWidget {
  const TrackPage({super.key});

  @override
  State<TrackPage> createState() => _TrackPageState();
}

class _TrackPageState extends State<TrackPage> {
  final _store = HistoryCollectStore();

  @override
  void initState() {
    super.initState();
    _store.loadTracks();
  }

  @override
  Widget build(BuildContext context) {
    return ViraPageScaffold(
      activeDestination: ViraDestination.following,
      onDestinationSelected: _openDestination,
      onSearch: () => Modular.to.pushNamed('/search'),
      onThemeToggle: () => Modular.get<ThemeStore>().toggleTheme(),
      onProfile: () => Modular.to.pushNamed('/settings'),
      child: Observer(
        builder: (_) {
          final entries = _store.trackList
              .map(
                (item) => ArchiveEntry(
                  id: item.animeUrl,
                  title: item.animeName,
                  coverUrl: item.cover,
                  subtitle: item.totalEpisodes > 0
                      ? '看到第 ${item.watchedEpisodes} 集 / 共 ${item.totalEpisodes} 集'
                      : '看到第 ${item.watchedEpisodes} 集',
                  meta: _timeAgo(item.lastUpdated ?? item.trackedAt),
                  sourceLabel: item.sourcePlugin,
                  progress: item.totalEpisodes > 0
                      ? item.watchedEpisodes / item.totalEpisodes
                      : 0,
                  statusLabel: _statusLabel(item.status),
                ),
              )
              .toList(growable: false);

          return PersonalArchiveView(
            title: '追番手账',
            description: '正在发生的故事、更新状态和观看进度，都安静地记在这里。',
            mode: ArchiveDisplayMode.progress,
            entries: entries,
            sections: const [
              ArchiveSection(id: 'track', label: '追番手账'),
              ArchiveSection(id: 'calendar', label: '放送日历'),
            ],
            selectedSectionId: 'track',
            onSectionSelected: (section) {
              if (section == 'calendar') Modular.to.navigate('/calendar');
            },
            onOpen: (entry) => Modular.to.pushNamed(
              '/detail?url=${Uri.encodeComponent(entry.id)}'
              '&name=${Uri.encodeComponent(entry.title)}',
            ),
            onRemove: (entry) => _store.removeTrack(entry.id),
          );
        },
      ),
    );
  }

  String _statusLabel(String? status) => switch (status) {
        'RELEASING' => '连载中',
        'FINISHED' => '已完结',
        'NOT_YET_RELEASED' => '未开播',
        _ => '待确认',
      };

  String _timeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inDays < 1) return '今天更新';
    if (diff.inDays < 7) return '${diff.inDays}天前更新';
    return '${time.month}月${time.day}日更新';
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
}
