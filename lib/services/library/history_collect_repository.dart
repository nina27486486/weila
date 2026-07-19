import '../../models/collect_item.dart';
import '../../models/history_item.dart';
import '../../models/track_item.dart';

abstract class HistoryCollectRepository {
  List<HistoryItem> getHistory();
  Future<void> addHistory(HistoryItem item);
  Future<void> removeHistory(String animeUrl);
  Future<void> clearHistory();

  List<CollectItem> getCollects();
  Future<void> addCollect(CollectItem item);
  Future<void> removeCollect(String animeUrl);
  bool isCollected(String animeUrl);

  List<TrackItem> getTracks();
  Future<void> addTrack(TrackItem item);
  Future<void> removeTrack(String animeUrl);
  bool isTracked(String animeUrl);
}
