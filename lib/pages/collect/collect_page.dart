import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_modular/flutter_modular.dart';

import '../../stores/history_collect_store.dart';
import '../../stores/theme_store.dart';
import '../../widgets/vira_page_chrome.dart';
import '../library/personal_archive_view.dart';
import '../../utils/app_routes.dart';

class CollectPage extends StatefulWidget {
  const CollectPage({super.key});

  @override
  State<CollectPage> createState() => _CollectPageState();
}

class _CollectPageState extends State<CollectPage> {
  final _store = Modular.get<HistoryCollectStore>();

  @override
  void initState() {
    super.initState();
    _store.loadCollects();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ViraPageScaffold(
      activeDestination: ViraDestination.library,
      onDestinationSelected: _openDestination,
      onSearch: () => Modular.to.pushNamed(AppRoutes.search),
      onThemeToggle: () => Modular.get<ThemeStore>().toggleTheme(),
      onProfile: () => Modular.to.pushNamed(AppRoutes.settings),
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
              if (section == 'history') Modular.to.navigate(AppRoutes.history);
            },
            onOpen: (entry) {
              final item = _store.collectList
                  .where((candidate) => candidate.animeUrl == entry.id)
                  .firstOrNull;
              Modular.to.pushNamed(
                AppRoutes.detail(
                  url: entry.id,
                  name: entry.title,
                  contentId: item?.contentId,
                ),
              );
            },
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
    final route = destination.route;
    if (destination != ViraDestination.library) {
      Modular.to.navigate(route);
    }
  }
}
