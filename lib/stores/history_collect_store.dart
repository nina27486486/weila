// ignore_for_file: library_private_types_in_public_api

import 'dart:async';

import 'package:mobx/mobx.dart';
import '../models/history_item.dart';
import '../models/collect_item.dart';
import '../models/track_item.dart';
import '../services/library/history_collect_repository.dart';
import '../services/library/library_event_bus.dart';
import '../services/library/media_metadata_service.dart';
import '../services/storage/storage_service.dart';

export '../services/library/history_collect_repository.dart';

part 'history_collect_store.g.dart';

class HistoryCollectStore extends _HistoryCollectStore
    with _$HistoryCollectStore {
  HistoryCollectStore({
    super.repository,
    super.metadataService,
    super.events,
  });
}

abstract class _HistoryCollectStore with Store {
  final HistoryCollectRepository _storage;
  final MediaMetadataService _metadataService;
  final LibraryEventBus _events;
  late final StreamSubscription<LibraryChangedEvent> _eventSubscription;

  _HistoryCollectStore({
    HistoryCollectRepository? repository,
    MediaMetadataService? metadataService,
    LibraryEventBus? events,
  })  : _storage = repository ?? StorageService(),
        _metadataService = metadataService ?? MediaMetadataService(),
        _events = events ?? LibraryEventBus.instance {
    _eventSubscription = _events.stream.listen(_handleLibraryEvent);
  }

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
  Future<int> refreshHistoryMetadata() async {
    loadHistory();
    final changed = await _metadataService.hydrateHistory(historyList);
    if (changed > 0) loadHistory();
    return changed;
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
    _publish(LibraryEventScope.history, 'add-history', item.animeUrl);
  }

  Future<void> removeHistory(String animeUrl) async {
    await _storage.removeHistory(animeUrl);
    loadHistory();
    _publish(LibraryEventScope.history, 'remove-history', animeUrl);
  }

  @action
  Future<void> clearHistory() async {
    await _storage.clearHistory();
    historyList.clear();
    _publish(LibraryEventScope.history, 'clear-history');
  }

  @action
  Future<void> addCollect(CollectItem item) async {
    await _storage.addCollect(item);
    _mutationCounter++;
    loadCollects();
    _publish(LibraryEventScope.collect, 'add-collect', item.animeUrl);
  }

  @action
  Future<void> removeCollect(String animeUrl) async {
    await _storage.removeCollect(animeUrl);
    _mutationCounter++;
    loadCollects();
    _publish(LibraryEventScope.collect, 'remove-collect', animeUrl);
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
    _publish(LibraryEventScope.track, 'add-track', item.animeUrl);
  }

  @action
  Future<void> removeTrack(String animeUrl) async {
    await _storage.removeTrack(animeUrl);
    _mutationCounter++;
    loadTracks();
    _publish(LibraryEventScope.track, 'remove-track', animeUrl);
  }

  /// 读取_mutationCounter以触发Observer重建
  bool isTracked(String animeUrl) {
    _mutationCounter; // 触发MobX依赖追踪
    return _storage.isTracked(animeUrl);
  }

  void dispose() {
    unawaited(_eventSubscription.cancel());
  }

  void _handleLibraryEvent(LibraryChangedEvent event) {
    switch (event.scope) {
      case LibraryEventScope.history:
        loadHistory();
      case LibraryEventScope.collect:
        _mutationCounter++;
        loadCollects();
      case LibraryEventScope.track:
        _mutationCounter++;
        loadTracks();
      case LibraryEventScope.download:
        break;
    }
  }

  void _publish(
    LibraryEventScope scope,
    String reason, [
    String? key,
  ]) {
    _events.publish(LibraryChangedEvent.now(
      scope: scope,
      reason: reason,
      key: key,
    ));
  }
}
