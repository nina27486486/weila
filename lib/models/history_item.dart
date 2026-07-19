import 'package:hive_ce/hive.dart';

part 'history_item.g.dart';

@HiveType(typeId: 3)
class HistoryItem extends HiveObject {
  @HiveField(0)
  String animeName;
  
  @HiveField(1)
  String animeUrl;
  
  @HiveField(2)
  String episodeName;
  
  @HiveField(3)
  String episodeUrl;
  
  @HiveField(4)
  String sourcePlugin;
  
  @HiveField(5)
  String? cover;
  
  @HiveField(6)
  Duration position;
  
  @HiveField(7)
  Duration duration;
  
  @HiveField(8)
  DateTime watchedAt;
  
  HistoryItem({
    required this.animeName,
    required this.animeUrl,
    required this.episodeName,
    required this.episodeUrl,
    required this.sourcePlugin,
    this.cover,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    DateTime? watchedAt,
  }) : watchedAt = watchedAt ?? DateTime.now();
}
