import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_modular/flutter_modular.dart';

import '../../stores/history_collect_store.dart';
import '../../stores/home_store.dart';
import '../../stores/theme_store.dart';
import '../../widgets/vira_page_chrome.dart';
import 'home_editorial_view.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _homeStore = HomeStore();
  final _trackStore = HistoryCollectStore();

  @override
  void initState() {
    super.initState();
    _loadPage();
  }

  void _loadPage() {
    _homeStore.loadAll();
    _trackStore.loadTracks();
  }

  @override
  Widget build(BuildContext context) {
    return ViraPageScaffold(
      activeDestination: ViraDestination.home,
      onDestinationSelected: _openDestination,
      onSearch: () => Modular.to.pushNamed('/search'),
      onThemeToggle: () => Modular.get<ThemeStore>().toggleTheme(),
      onProfile: () => Modular.to.pushNamed('/settings'),
      child: Observer(
        builder: (_) {
          final continueStories = _trackStore.trackList
              .take(8)
              .map(
                (item) => HomeContinueStory(
                  title: item.animeName,
                  coverUrl: item.cover,
                  progressLabel: item.totalEpisodes > 0
                      ? '看到第 ${item.watchedEpisodes} 集 / 共 ${item.totalEpisodes} 集'
                      : '看到第 ${item.watchedEpisodes} 集',
                  updatedLabel: _timeAgo(item.lastUpdated ?? item.trackedAt),
                  animeUrl: item.animeUrl,
                ),
              )
              .toList(growable: false);

          final hasAnime = _homeStore.latestList.isNotEmpty ||
              _homeStore.seasonalList.isNotEmpty ||
              _homeStore.trendingList.isNotEmpty;
          final isLoading = !hasAnime &&
              (_homeStore.isLoadingLatest ||
                  _homeStore.isLoadingSeasonal ||
                  _homeStore.isLoadingTrending);

          return HomeEditorialView(
            latestItems: _homeStore.latestList,
            seasonalItems: _homeStore.seasonalList,
            trendingItems: _homeStore.trendingList,
            continueStories: continueStories,
            isLoading: isLoading,
            isSeasonalLoading: _homeStore.isLoadingSeasonal,
            isTrendingLoading: _homeStore.isLoadingTrending,
            errorMessage: _homeStore.errorMessage,
            onOpenAnime: _openDetail,
            onOpenContinue: (story) => Modular.to.pushNamed(
              '/detail?url=${Uri.encodeComponent(story.animeUrl)}'
              '&name=${Uri.encodeComponent(story.title)}',
            ),
            onRetry: _loadPage,
            onOpenHistory: () => Modular.to.pushNamed('/history'),
            onOpenCalendar: () => Modular.to.pushNamed('/calendar'),
            onOpenRanking: () => Modular.to.pushNamed('/ranking'),
          );
        },
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

    if (destination != ViraDestination.home) {
      Modular.to.navigate(route);
    }
  }

  void _openDetail(Map<String, dynamic> item) {
    Modular.to.pushNamed(
      '/detail?url=${Uri.encodeComponent(item['url']?.toString() ?? '')}'
      '&name=${Uri.encodeComponent(item['name']?.toString() ?? '')}',
    );
  }

  String _timeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes}分钟前';
    if (diff.inDays < 1) return '${diff.inHours}小时前';
    if (diff.inDays < 7) return '${diff.inDays}天前';
    return '${time.month}月${time.day}日';
  }
}
