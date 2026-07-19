import 'package:hive_ce/hive.dart';

part 'track_item.g.dart';

@HiveType(typeId: 5)
class TrackItem extends HiveObject {
  @HiveField(0)
  String animeName;

  @HiveField(1)
  String animeUrl;

  @HiveField(2)
  String sourcePlugin;

  @HiveField(3)
  String? cover;

  @HiveField(4)
  String? status; // RELEASING, NOT_YET_RELEASED, FINISHED, etc.

  @HiveField(5)
  int totalEpisodes;

  @HiveField(6)
  int watchedEpisodes;

  @HiveField(7)
  DateTime trackedAt;

  @HiveField(8)
  DateTime? lastUpdated;

  TrackItem({
    required this.animeName,
    required this.animeUrl,
    required this.sourcePlugin,
    this.cover,
    this.status,
    this.totalEpisodes = 0,
    this.watchedEpisodes = 0,
    DateTime? trackedAt,
    this.lastUpdated,
  }) : trackedAt = trackedAt ?? DateTime.now();
}
