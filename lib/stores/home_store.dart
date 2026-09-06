// ignore_for_file: library_private_types_in_public_api

import 'package:mobx/mobx.dart';
import '../services/home/home_feed_service.dart';
import '../../utils/logger.dart';

part 'home_store.g.dart';

class HomeStore = _HomeStore with _$HomeStore;

abstract class _HomeStore with Store {
  _HomeStore({HomeFeedDataSource? feedService})
      : _feedService = feedService ?? HomeFeedService();

  final HomeFeedDataSource _feedService;

  @observable
  ObservableList<Map<String, dynamic>> latestList = ObservableList.of([]);

  @observable
  ObservableList<Map<String, dynamic>> trendingList = ObservableList.of([]);

  @observable
  bool isLoadingLatest = false;

  @observable
  bool isLoadingTrending = false;

  @observable
  ObservableList<Map<String, dynamic>> seasonalList = ObservableList.of([]);

  @observable
  bool isLoadingSeasonal = false;

  // 三个信息流独立记录错误，避免互相覆盖或误清；
  // errorMessage 聚合给整体空态提示使用。
  @observable
  String? latestError;

  @observable
  String? trendingError;

  @observable
  String? seasonalError;

  String? get errorMessage => latestError ?? trendingError ?? seasonalError;

  @action
  Future<void> loadLatest() async {
    isLoadingLatest = true;
    latestError = null;
    try {
      final results = await _feedService.loadLatest();
      latestList.clear();
      latestList.addAll(results);
    } catch (e) {
      Log.e('HomeStore', '加载最新番剧失败', e);
      latestError = '加载最新番剧失败，请检查网络';
    } finally {
      isLoadingLatest = false;
    }
  }

  @action
  Future<void> loadTrending() async {
    isLoadingTrending = true;
    trendingError = null;
    try {
      final results = await _feedService.loadTrending();
      trendingList.clear();
      trendingList.addAll(results);
    } catch (e) {
      Log.e('HomeStore', '加载热门番剧失败', e);
      trendingError = '加载热门番剧失败，请检查网络';
    } finally {
      isLoadingTrending = false;
    }
  }

  @action
  Future<void> loadSeasonal() async {
    isLoadingSeasonal = true;
    seasonalError = null;
    try {
      final results = await _feedService.loadSeasonal();

      seasonalList.clear();
      seasonalList.addAll(results);
    } catch (e) {
      Log.e('HomeStore', '加载季度新番失败', e);
      seasonalError = '加载季度新番失败，请检查网络';
    } finally {
      isLoadingSeasonal = false;
    }
  }

  @action
  Future<void> loadAll() async {
    await Future.wait([loadLatest(), loadTrending(), loadSeasonal()]);
  }
}
