import '../plugin/plugin_service.dart';

abstract interface class HomeCatalogGateway {
  Future<List<Map<String, dynamic>>> getCmsLatest(String pluginApi);

  Future<List<Map<String, dynamic>>> getSeasonalAnime();

  Future<List<Map<String, dynamic>>> getPopularAnime();
}

class PluginHomeCatalogGateway implements HomeCatalogGateway {
  PluginHomeCatalogGateway({PluginService? pluginService})
      : _pluginService = pluginService ?? PluginService();

  final PluginService _pluginService;

  @override
  Future<List<Map<String, dynamic>>> getCmsLatest(String pluginApi) {
    return _pluginService.getCmsLatest(pluginApi: pluginApi, page: 1);
  }

  @override
  Future<List<Map<String, dynamic>>> getPopularAnime() {
    return _pluginService.getJikanTopAnime(
      filter: 'bypopularity',
      type: 'tv',
    );
  }

  @override
  Future<List<Map<String, dynamic>>> getSeasonalAnime() {
    return _pluginService.getJikanSeasonNow();
  }
}

abstract interface class HomeFeedDataSource {
  Future<List<Map<String, dynamic>>> loadLatest();

  Future<List<Map<String, dynamic>>> loadTrending();

  Future<List<Map<String, dynamic>>> loadSeasonal();
}

class HomeFeedService implements HomeFeedDataSource {
  HomeFeedService({HomeCatalogGateway? gateway})
      : _gateway = gateway ?? PluginHomeCatalogGateway();

  final HomeCatalogGateway _gateway;

  @override
  Future<List<Map<String, dynamic>>> loadLatest() {
    return _firstNonEmpty([
      () => _gateway.getCmsLatest('cms_yinhua'),
      () => _gateway.getCmsLatest('cms_ffzy'),
    ]);
  }

  @override
  Future<List<Map<String, dynamic>>> loadTrending() {
    return _firstNonEmpty([
      () => _gateway.getCmsLatest('cms_ffzy'),
      _gateway.getPopularAnime,
      () => _gateway.getCmsLatest('cms_yinhua'),
    ]);
  }

  @override
  Future<List<Map<String, dynamic>>> loadSeasonal() {
    return _firstNonEmpty([
      _gateway.getSeasonalAnime,
      () => _gateway.getCmsLatest('cms_yinhua'),
      () => _gateway.getCmsLatest('cms_ffzy'),
    ]);
  }

  Future<List<Map<String, dynamic>>> _firstNonEmpty(
    List<Future<List<Map<String, dynamic>>> Function()> loaders,
  ) async {
    for (final loader in loaders) {
      try {
        final result = await loader();
        if (result.isNotEmpty) return result;
      } catch (_) {
        // A feed source going offline should not blank the whole home section.
      }
    }
    return const [];
  }
}
