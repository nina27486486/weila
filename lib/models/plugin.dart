import 'package:hive_ce/hive.dart';

part 'plugin.g.dart';

@HiveType(typeId: 0)
class Plugin extends HiveObject {
  @HiveField(0)
  String api;
  
  @HiveField(1)
  String name;
  
  @HiveField(2)
  String version;
  
  @HiveField(3)
  String baseUrl;
  
  @HiveField(4)
  String searchURL;
  
  @HiveField(5)
  String searchList;
  
  @HiveField(6)
  String searchName;
  
  @HiveField(7)
  String searchResult;
  
  @HiveField(8)
  String chapterRoads;
  
  @HiveField(9)
  String chapterResult;
  
  @HiveField(10)
  String userAgent;
  
  @HiveField(11)
  String? referer;
  
  @HiveField(12)
  bool enabled;
  
  Plugin({
    required this.api,
    required this.name,
    this.version = '1.0.0',
    required this.baseUrl,
    required this.searchURL,
    required this.searchList,
    required this.searchName,
    required this.searchResult,
    required this.chapterRoads,
    required this.chapterResult,
    this.userAgent = '',
    this.referer,
    this.enabled = true,
  });
  
  factory Plugin.fromJson(Map<String, dynamic> json) {
    return Plugin(
      api: json['api'] ?? '',
      name: json['name'] ?? '',
      version: json['version'] ?? '1.0.0',
      baseUrl: json['baseUrl'] ?? '',
      searchURL: json['searchURL'] ?? '',
      searchList: json['searchList'] ?? '',
      searchName: json['searchName'] ?? '',
      searchResult: json['searchResult'] ?? '',
      chapterRoads: json['chapterRoads'] ?? '',
      chapterResult: json['chapterResult'] ?? '',
      userAgent: json['userAgent'] ?? '',
      referer: json['referer'],
      enabled: json['enabled'] ?? true,
    );
  }
  
  Map<String, dynamic> toJson() => {
    'api': api,
    'name': name,
    'version': version,
    'baseUrl': baseUrl,
    'searchURL': searchURL,
    'searchList': searchList,
    'searchName': searchName,
    'searchResult': searchResult,
    'chapterRoads': chapterRoads,
    'chapterResult': chapterResult,
    'userAgent': userAgent,
    'referer': referer,
    'enabled': enabled,
  };
}
