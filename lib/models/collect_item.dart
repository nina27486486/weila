import 'package:hive_ce/hive.dart';

part 'collect_item.g.dart';

@HiveType(typeId: 4)
class CollectItem extends HiveObject {
  @HiveField(0)
  String animeName;
  
  @HiveField(1)
  String animeUrl;
  
  @HiveField(2)
  String sourcePlugin;
  
  @HiveField(3)
  String? cover;
  
  @HiveField(4)
  String? description;
  
  @HiveField(5)
  DateTime collectedAt;
  
  CollectItem({
    required this.animeName,
    required this.animeUrl,
    required this.sourcePlugin,
    this.cover,
    this.description,
    DateTime? collectedAt,
  }) : collectedAt = collectedAt ?? DateTime.now();
}
