import 'package:flutter_modular/flutter_modular.dart';

import 'debug/danmaku_debug_config.dart';
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
import 'pages/debug/danmaku_debug_page.dart';
import 'stores/theme_store.dart';
import 'utils/app_routes.dart';

class AppModule extends Module {
  @override
  void binds(i) {
    i.addLazySingleton<ThemeStore>(() => ThemeStore());
  }

  @override
  void routes(r) {
    r.child(
      AppRoutes.home,
      child: (context) => const HomePage(),
    );
    r.child(
      AppRoutes.search,
      child: (context) => SearchPage(
        initialQuery: r.args.queryParams['q'],
      ),
    );
    r.child(
      AppRoutes.detailPath,
      child: (context) => DetailPage(
        contentId: r.args.queryParams['contentId'],
        animeUrl: r.args.queryParams['url'] ?? '',
        animeName: r.args.queryParams['name'] ?? '',
      ),
    );
    r.child(
      AppRoutes.playerPath,
      child: (context) => PlayerPage(
        videoUrl: r.args.queryParams['url'] ?? '',
        title: r.args.queryParams['title'] ?? '',
        animeUrl: r.args.queryParams['animeUrl'] ?? '',
        animeName: r.args.queryParams['animeName'] ?? '',
        coverUrl: r.args.queryParams['cover'],
        episodeIndex: int.tryParse(r.args.queryParams['ep'] ?? '0') ?? 0,
        sourcePlugin: r.args.queryParams['source'] ?? '',
        contentId: r.args.queryParams['contentId'],
      ),
    );
    r.child(
      AppRoutes.history,
      child: (context) => const HistoryPage(),
    );
    r.child(
      AppRoutes.collect,
      child: (context) => const CollectPage(),
    );
    r.child(
      AppRoutes.track,
      child: (context) => const TrackPage(),
    );
    r.child(
      AppRoutes.settings,
      child: (context) => const SettingsPage(),
    );
    if (danmakuDebugModeEnabled) {
      r.child(
        '/danmaku-debug',
        child: (context) => const DanmakuDebugPage(),
      );
    }
    r.child(
      AppRoutes.plugins,
      child: (context) => const PluginListPage(),
    );
    r.child(
      AppRoutes.pluginAdd,
      child: (context) => const PluginAddPage(),
    );
    r.child(
      AppRoutes.pluginDetail,
      child: (context) => PluginDetailPage(
        pluginApi: r.args.queryParams['api'] ?? '',
      ),
    );
    r.child(
      AppRoutes.animeList,
      child: (context) => r.args.queryParams['type'] == 'movie'
          ? AnimeListPage.movies()
          : AnimeListPage.anime(),
    );
    r.child(
      AppRoutes.calendar,
      child: (context) => const CalendarPage(),
    );
    r.child(
      AppRoutes.ranking,
      child: (context) => const RankingPage(),
    );
    r.child(
      AppRoutes.category,
      child: (context) => const CategoryBrowsePage(),
    );
    r.child(
      AppRoutes.download,
      child: (context) => const DownloadPage(),
    );
  }
}
