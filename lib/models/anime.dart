import 'package:hive_ce/hive.dart';

part 'anime.g.dart';

@HiveType(typeId: 1)
class Anime extends HiveObject {
  @HiveField(0)
  String name;
  
  @HiveField(1)
  String url;
  
  @HiveField(2)
  String? cover;
  
  @HiveField(3)
  String? description;
  
  @HiveField(4)
  String sourcePlugin;
  
  @HiveField(5)
  List<Episode> episodes;
  
  Anime({
    required this.name,
    required this.url,
    this.cover,
    this.description,
    required this.sourcePlugin,
    this.episodes = const [],
  });
}

@HiveType(typeId: 2)
class Episode extends HiveObject {
  @HiveField(0)
  String name;
  
  @HiveField(1)
  String url;
  
  @HiveField(2)
  int index;
  
  Episode({
    required this.name,
    required this.url,
    this.index = 0,
  });
}
