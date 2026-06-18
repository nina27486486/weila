import 'package:flutter_modular/flutter_modular.dart';
import 'pages/home/home_page.dart';
import 'pages/search/search_page.dart';
import 'pages/detail/detail_page.dart';
import 'pages/player/player_page.dart';
import 'pages/history/history_page.dart';
import 'pages/collect/collect_page.dart';
import 'pages/track/track_page.dart';
import 'pages/settings/settings_page.dart';
import 'pages/settings/plugin_list_page.dart';
import 'pages/settings/plugin_add_page.dart';
import 'pages/settings/plugin_detail_page.dart';
import 'pages/discover/anime_list_page.dart';
import 'pages/discover/calendar_page.dart';
import 'pages/discover/ranking_page.dart';
import 'pages/discover/category_browse_page.dart';
import 'pages/download/download_page.dart';
import 'services/plugin/plugin_service.dart';

class AppModule extends Module {
  @override
  void binds(i) {
    // 全局依赖注入
  }

  @override
  void routes(r) {
    r.child(
      '/',
      child: (context) => const HomePage(),
    );
    r.child(
      '/search',
      child: (context) => SearchPage(
        initialQuery: r.args.queryParams['q'],
      ),
    );
    r.child(
      '/detail',
      child: (context) => DetailPage(
        animeUrl: r.args.queryParams['url'] ?? '',
        animeName: r.args.queryParams['name'] ?? '',
      ),
    );
    r.child(
      '/player',
      child: (context) => PlayerPage(
        videoUrl: r.args.queryParams['url'] ?? '',
        title: r.args.queryParams['title'] ?? '',
        animeUrl: r.args.queryParams['animeUrl'] ?? '',
        episodeIndex: int.tryParse(r.args.queryParams['ep'] ?? '0') ?? 0,
        sourcePlugin: r.args.queryParams['source'] ?? '',
      ),
    );
    r.child(
      '/history',
      child: (context) => const HistoryPage(),
    );
    r.child(
      '/collect',
      child: (context) => const CollectPage(),
    );
    r.child(
      '/track',
      child: (context) => const TrackPage(),
    );
    r.child(
      '/settings',
      child: (context) => const SettingsPage(),
    );
    r.child(
      '/settings/plugins',
      child: (context) => const PluginListPage(),
    );
    r.child(
      '/settings/plugin-add',
      child: (context) => const PluginAddPage(),
    );
    r.child(
      '/settings/plugin-detail',
      child: (context) => PluginDetailPage(
        pluginApi: r.args.queryParams['api'] ?? '',
      ),
    );
    r.child(
      '/anime-list',
      child: (context) {
        final type = r.args.queryParams['type'] ?? 'anime';
        if (type == 'movie') {
          return AnimeListPage(
            title: '剧场版',
            categoryIds: PluginService.cmsCategories.map((k, v) => MapEntry(k, (v.last['id'] as int))),
          );
        }
        return AnimeListPage(
          title: '番剧',
          categoryIds: PluginService.cmsCategories.map((k, v) => MapEntry(k, (v.firstWhere((c) => c['name']?.toString().contains('日本') == true || c['name']?.toString().contains('日韩') == true, orElse: () => v.first)['id'] as int))),
        );
      },
    );
    r.child(
      '/calendar',
      child: (context) => const CalendarPage(),
    );
    r.child(
      '/ranking',
      child: (context) => const RankingPage(),
    );
    r.child(
      '/category',
      child: (context) => const CategoryBrowsePage(),
    );
    r.child(
      '/download',
      child: (context) => const DownloadPage(),
    );
  }
}
