import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weila/app_module.dart';
import 'package:weila/models/download_item.dart';
import 'package:weila/pages/player/player_page.dart';
import 'package:weila/pages/settings/settings_page.dart';
import 'package:weila/platform/app_capabilities.dart';
import 'package:weila/platform/fullscreen_controller.dart';
import 'package:weila/platform/player_download_actions.dart';
import 'package:weila/services/danmaku/dandanplay_credential_manager.dart';
import 'package:weila/services/danmaku/unavailable_danmaku_credential_store.dart';
import 'package:weila/services/download/download_settings.dart';
import 'package:weila/utils/app_routes.dart';

void main() {
  tearDown(cleanModular);

  DanmakuCredentialManager credentials() => DanmakuCredentialManager.platform(
        store: const UnavailableDanmakuCredentialStore(),
      );

  PlayerDownloadActions actions() => PlayerDownloadActions(
        isDownloaded: (_) async => false,
        getAllDownloads: () => [],
        addDownload: (_) async {},
      );

  testWidgets('Android routes need no download implementation', (tester) async {
    final routes = _routeBuilders(AppModule(
      credentialManager: credentials(),
      capabilities: AppCapabilities.androidCompileBaseline,
      fullscreenController: const NoopFullscreenController(),
    ));

    expect(routes, contains(AppRoutes.home));
    expect(routes, isNot(contains(AppRoutes.download)));
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (context) {
        final player = routes[AppRoutes.playerPath]!(context) as PlayerPage;
        final settings = routes[AppRoutes.settings]!(context) as SettingsPage;
        expect(player.downloadActions, isNull);
        expect(settings.configureDownloads, isNull);
        expect(player.capabilities.downloads, isFalse);
        expect(settings.capabilities.downloads, isFalse);
        return const SizedBox();
      }),
    ));
  });

  testWidgets('Windows routes forward download bindings and preserve defaults',
      (tester) async {
    final downloads = actions();
    Future<void> configure(DownloadSettings settings) async {}
    const downloadPage = SizedBox(key: ValueKey('injected-download-page'));
    final routes = _routeBuilders(AppModule(
      credentialManager: credentials(),
      capabilities: AppCapabilities.windows,
      fullscreenController: const NoopFullscreenController(),
      downloadActions: downloads,
      configureDownloads: configure,
      downloadPageBuilder: (_) => downloadPage,
    ));

    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (context) {
        final player = routes[AppRoutes.playerPath]!(context) as PlayerPage;
        final settings = routes[AppRoutes.settings]!(context) as SettingsPage;
        expect(player.downloadActions, same(downloads));
        expect(settings.configureDownloads, same(configure));
        expect(routes[AppRoutes.download]!(context), same(downloadPage));
        expect(player.videoUrl, isEmpty);
        expect(player.title, isEmpty);
        expect(player.animeUrl, isEmpty);
        expect(player.animeName, isEmpty);
        expect(player.coverUrl, isNull);
        expect(player.episodeIndex, 0);
        expect(player.sourcePlugin, isEmpty);
        expect(player.contentId, isNull);
        return const SizedBox();
      }),
    ));
  });

  test('Windows composition rejects missing download wiring', () {
    for (final missing in ['actions', 'configure', 'page']) {
      expect(
        () => AppModule(
          credentialManager: credentials(),
          capabilities: AppCapabilities.windows,
          fullscreenController: const NoopFullscreenController(),
          downloadActions: missing == 'actions' ? null : actions(),
          configureDownloads: missing == 'configure' ? null : (_) async {},
          downloadPageBuilder:
              missing == 'page' ? null : (_) => const SizedBox(),
        ),
        throwsAssertionError,
        reason: missing,
      );
    }
  });

  test('download actions preserve inputs, results and failures', () async {
    final item = DownloadItem(
      animeName: 'Example anime',
      animeUrl: '/anime/1',
      episodeName: 'Episode 1',
      episodeUrl: 'https://media.example.test/episode.m3u8',
      sourcePlugin: 'example-source',
      m3u8Url: 'https://media.example.test/episode.m3u8',
    );
    final items = [item];
    String? checkedUrl;
    DownloadItem? queuedItem;
    final failure = StateError('download unavailable');
    final downloads = PlayerDownloadActions(
      isDownloaded: (url) async {
        checkedUrl = url;
        return true;
      },
      getAllDownloads: () => items,
      addDownload: (value) async {
        queuedItem = value;
        throw failure;
      },
    );

    expect(await downloads.isDownloaded(item.episodeUrl), isTrue);
    expect(checkedUrl, item.episodeUrl);
    expect(downloads.getAllDownloads(), same(items));
    await expectLater(downloads.addDownload(item), throwsA(same(failure)));
    expect(queuedItem, same(item));
  });
}

Map<String, WidgetBuilder> _routeBuilders(AppModule module) {
  final manager = RouteManager();
  module.routes(manager);
  return {
    for (final route in manager.allRoutes)
      route.name: (route as ChildRoute).child!,
  };
}
