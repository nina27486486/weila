import 'package:mobx/mobx.dart';
import '../models/history_item.dart';
import '../models/collect_item.dart';
import '../models/track_item.dart';
import '../services/storage/storage_service.dart';

part 'history_collect_store.g.dart';

class HistoryCollectStore = _HistoryCollectStore with _$HistoryCollectStore;

abstract class _HistoryCollectStore with Store {
  final StorageService _storage = StorageService();

  /// 变更计数器：每次增删操作+1，让isCollected/isTracked触发Observer重建
  @observable
  int _mutationCounter = 0;

  @observable
  ObservableList<HistoryItem> historyList = ObservableList.of([]);

  @observable
  ObservableList<CollectItem> collectList = ObservableList.of([]);

  @observable
  ObservableList<TrackItem> trackList = ObservableList.of([]);

  @action
  void loadHistory() {
    historyList.clear();
    historyList.addAll(_storage.getHistory());
  }

  @action
  void loadCollects() {
    collectList.clear();
    collectList.addAll(_storage.getCollects());
  }

  @action
  void loadTracks() {
    trackList.clear();
    trackList.addAll(_storage.getTracks());
  }

  @action
  Future<void> addHistory(HistoryItem item) async {
    await _storage.addHistory(item);
    loadHistory();
  }

  @action
  Future<void> clearHistory() async {
    await _storage.clearHistory();
    historyList.clear();
  }

  @action
  Future<void> addCollect(CollectItem item) async {
    await _storage.addCollect(item);
    _mutationCounter++;
    loadCollects();
  }

  @action
  Future<void> removeCollect(String animeUrl) async {
    await _storage.removeCollect(animeUrl);
    _mutationCounter++;
    loadCollects();
  }

  /// 读取_mutationCounter以触发Observer重建
  bool isCollected(String animeUrl) {
    _mutationCounter; // 触发MobX依赖追踪
    return _storage.isCollected(animeUrl);
  }

  @action
  Future<void> addTrack(TrackItem item) async {
    await _storage.addTrack(item);
    _mutationCounter++;
    loadTracks();
  }

  @action
  Future<void> removeTrack(String animeUrl) async {
    await _storage.removeTrack(animeUrl);
    _mutationCounter++;
    loadTracks();
  }

  /// 读取_mutationCounter以触发Observer重建
  bool isTracked(String animeUrl) {
    _mutationCounter; // 触发MobX依赖追踪
    return _storage.isTracked(animeUrl);
  }
}
