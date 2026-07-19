import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_modular/flutter_modular.dart';

import '../../stores/history_collect_store.dart';
import '../../stores/theme_store.dart';
import '../../widgets/vira_page_chrome.dart';
import '../library/personal_archive_view.dart';

class CollectPage extends StatefulWidget {
  const CollectPage({super.key});

  @override
  State<CollectPage> createState() => _CollectPageState();
}

class _CollectPageState extends State<CollectPage> {
  final _store = HistoryCollectStore();

  @override
  void initState() {
    super.initState();
    _store.loadCollects();
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
          final entries = _store.collectList
              .map(
                (item) => ArchiveEntry(
                  id: item.animeUrl,
                  title: item.animeName,
                  coverUrl: item.cover,
                  subtitle: item.description ?? '',
                  meta: '收藏于 ${_dateLabel(item.collectedAt)}',
                  sourceLabel: _sourceLabel(item.sourcePlugin),
                ),
              )
              .toList(growable: false);

          return PersonalArchiveView(
            title: '我的资料库',
            description: '把值得回看的作品收进自己的动画书架。',
            mode: ArchiveDisplayMode.poster,
            entries: entries,
            sections: const [
              ArchiveSection(id: 'collect', label: '收藏夹'),
              ArchiveSection(id: 'history', label: '观看足迹'),
            ],
            selectedSectionId: 'collect',
            onSectionSelected: (section) {
              if (section == 'history') Modular.to.navigate('/history');
            },
            onOpen: (entry) => Modular.to.pushNamed(
              '/detail?url=${Uri.encodeComponent(entry.id)}'
              '&name=${Uri.encodeComponent(entry.title)}',
            ),
            onRemove: (entry) => _store.removeCollect(entry.id),
          );
        },
      ),
    );
  }

  String _dateLabel(DateTime date) => '${date.month}月${date.day}日';

  String _sourceLabel(String source) => switch (source) {
        'cms_yinhua' => '樱花动漫',
        'cms_ffzy' => '非凡资源',
        _ => source,
      };

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
