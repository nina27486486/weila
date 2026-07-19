import 'package:flutter_test/flutter_test.dart';
import 'package:weila/models/collect_item.dart';
import 'package:weila/models/history_item.dart';
import 'package:weila/models/track_item.dart';
import 'package:weila/services/library/library_event_bus.dart';
import 'package:weila/stores/history_collect_store.dart';

void main() {
  test('track changes from another writer refresh the store automatically',
      () async {
    final events = LibraryEventBus();
    final repository = _FakeHistoryCollectRepository();
    final store = HistoryCollectStore(
      repository: repository,
      events: events,
    );
    addTearDown(store.dispose);
    addTearDown(events.dispose);

    store.loadTracks();
    expect(store.trackList, isEmpty);
    expect(repository.trackLoads, 1);

    repository.tracks = [
      TrackItem(
        animeName: 'Vira Diary',
        animeUrl: 'anime:1',
        sourcePlugin: 'test',
        watchedEpisodes: 3,
      ),
    ];
    events.publish(const LibraryChangedEvent(
      scope: LibraryEventScope.track,
      reason: 'external-update',
      key: 'anime:1',
    ));
    await Future<void>.delayed(Duration.zero);

    expect(store.trackList.single.animeName, 'Vira Diary');
    expect(repository.trackLoads, 2);
    expect(repository.historyLoads, 0);
  });

  test('disposed stores stop reacting to library events', () async {
    final events = LibraryEventBus();
    final repository = _FakeHistoryCollectRepository();
    final store = HistoryCollectStore(
      repository: repository,
      events: events,
    );

    store.loadHistory();
    store.dispose();
    repository.history = [
      HistoryItem(
        animeName: 'After Dispose',
        animeUrl: 'anime:2',
        episodeName: 'Episode 1',
        episodeUrl: 'episode:1',
        sourcePlugin: 'test',
      ),
    ];
    events.publish(const LibraryChangedEvent(
      scope: LibraryEventScope.history,
      reason: 'external-update',
    ));
    await Future<void>.delayed(Duration.zero);

    expect(store.historyList, isEmpty);
    expect(repository.historyLoads, 1);

    events.dispose();
  });
}

class _FakeHistoryCollectRepository implements HistoryCollectRepository {
  var history = <HistoryItem>[];
  var collects = <CollectItem>[];
  var tracks = <TrackItem>[];
  var historyLoads = 0;
  var collectLoads = 0;
  var trackLoads = 0;

  @override
  List<HistoryItem> getHistory() {
    historyLoads++;
    return List.of(history);
  }

  @override
  Future<void> addHistory(HistoryItem item) async {
    history.add(item);
  }

  @override
  Future<void> clearHistory() async {
    history.clear();
  }

  @override
  Future<void> removeHistory(String animeUrl) async {
    history.removeWhere((item) => item.animeUrl == animeUrl);
  }

  @override
  List<CollectItem> getCollects() {
    collectLoads++;
    return List.of(collects);
  }

  @override
  Future<void> addCollect(CollectItem item) async {
    collects.add(item);
  }

  @override
  Future<void> removeCollect(String animeUrl) async {
    collects.removeWhere((item) => item.animeUrl == animeUrl);
  }

  @override
  bool isCollected(String animeUrl) {
    return collects.any((item) => item.animeUrl == animeUrl);
  }

  @override
  List<TrackItem> getTracks() {
    trackLoads++;
    return List.of(tracks);
  }

  @override
  Future<void> addTrack(TrackItem item) async {
    tracks.add(item);
  }

  @override
  Future<void> removeTrack(String animeUrl) async {
    tracks.removeWhere((item) => item.animeUrl == animeUrl);
  }

  @override
  bool isTracked(String animeUrl) {
    return tracks.any((item) => item.animeUrl == animeUrl);
  }
}
