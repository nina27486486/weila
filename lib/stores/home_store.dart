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

  @observable
  String? errorMessage;

  @action
  Future<void> loadLatest() async {
    isLoadingLatest = true;
    errorMessage = null;
    try {
      final results = await _feedService.loadLatest();
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
      final results = await _feedService.loadTrending();
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
  Future<void> loadSeasonal() async {
    isLoadingSeasonal = true;
    try {
      final results = await _feedService.loadSeasonal();

      seasonalList.clear();
      seasonalList.addAll(results);
    } catch (e) {
      Log.e('HomeStore', '加载季度新番失败', e);
    } finally {
      isLoadingSeasonal = false;
    }
  }

  @action
  Future<void> loadAll() async {
    await Future.wait([loadLatest(), loadTrending(), loadSeasonal()]);
  }
}
