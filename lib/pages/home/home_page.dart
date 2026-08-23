import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_modular/flutter_modular.dart';

import '../../stores/history_collect_store.dart';
import '../../stores/home_store.dart';
import '../../stores/theme_store.dart';
import '../../widgets/vira_page_chrome.dart';
import 'home_editorial_view.dart';
import '../../utils/app_routes.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _homeStore = Modular.get<HomeStore>();
  final _trackStore = Modular.get<HistoryCollectStore>();

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
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ViraPageScaffold(
      activeDestination: ViraDestination.home,
      onDestinationSelected: _openDestination,
      onSearch: () => Modular.to.pushNamed(AppRoutes.search),
      onThemeToggle: () => Modular.get<ThemeStore>().toggleTheme(),
      onProfile: () => Modular.to.pushNamed(AppRoutes.settings),
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
                  contentId: item.contentId,
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
              AppRoutes.detail(
                url: story.animeUrl,
                name: story.title,
                contentId: story.contentId,
              ),
            ),
            onRetry: _loadPage,
            onOpenHistory: () => Modular.to.pushNamed(AppRoutes.history),
            onOpenCalendar: () => Modular.to.pushNamed(AppRoutes.calendar),
            onOpenRanking: () => Modular.to.pushNamed(AppRoutes.ranking),
          );
        },
      ),
    );
  }

  void _openDestination(ViraDestination destination) {
    final route = destination.route;

    if (destination != ViraDestination.home) {
      Modular.to.navigate(route);
    }
  }

  void _openDetail(Map<String, dynamic> item) {
    Modular.to.pushNamed(
      AppRoutes.detail(
        url: item['url']?.toString(),
        name: item['name']?.toString(),
      ),
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
