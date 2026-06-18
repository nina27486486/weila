import 'package:mobx/mobx.dart';
import '../services/plugin/plugin_service.dart';
import '../../utils/logger.dart';

part 'home_store.g.dart';

class HomeStore = _HomeStore with _$HomeStore;

abstract class _HomeStore with Store {
  final PluginService _pluginService = PluginService();

  @observable
  ObservableList<Map<String, dynamic>> latestList = ObservableList.of([]);

  @observable
  ObservableList<Map<String, dynamic>> trendingList = ObservableList.of([]);

  @observable
  bool isLoadingLatest = false;

  @observable
  bool isLoadingTrending = false;

  @observable
  String? errorMessage;

  @action
  Future<void> loadLatest() async {
    isLoadingLatest = true;
    errorMessage = null;
    try {
      final results = await _pluginService.getCmsLatest(pluginApi: 'cms_yinhua', page: 1);
      latestList.clear();
      latestList.addAll(results);
    } catch (e) {
      Log.e('HomeStore', '加载最新番剧失败', e);
      errorMessage = '加载最新番剧失败，请检查网络';
    } finally {
      isLoadingLatest = false;
    }
  }

  @action
  Future<void> loadTrending() async {
    isLoadingTrending = true;
    errorMessage = null;
    try {
      final results = await _pluginService.getCmsLatest(pluginApi: 'cms_ffzy', page: 1);
      trendingList.clear();
      trendingList.addAll(results);
    } catch (e) {
      Log.e('HomeStore', '加载热门番剧失败', e);
      errorMessage = '加载热门番剧失败，请检查网络';
    } finally {
      isLoadingTrending = false;
    }
  }

  @action
  Future<void> loadAll() async {
    await Future.wait([loadLatest(), loadTrending()]);
  }
}
