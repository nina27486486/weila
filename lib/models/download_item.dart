import 'package:hive_ce/hive.dart';

part 'download_item.g.dart';

/// 下载状态
/// 0=等待中, 1=下载中, 2=已完成, 3=已暂停, 4=失败
@HiveType(typeId: 6)
class DownloadItem extends HiveObject {
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
  String? localPath;

  /// 0=等待中, 1=下载中, 2=已完成, 3=已暂停, 4=失败
  @HiveField(7)
  int status;

  /// 下载进度 0.0 ~ 1.0
  @HiveField(8)
  double progress;

  /// 总分片数
  @HiveField(9)
  int totalSegments;

  /// 已下载分片数
  @HiveField(10)
  int downloadedSegments;

  @HiveField(11)
  DateTime createdAt;

  /// 总文件大小（字节）
  @HiveField(12)
  int fileSize;

  /// m3u8 playlist URL（用于下载）
  @HiveField(13)
  String m3u8Url;

  /// Referer header（从 image URL origin 推导）
  @HiveField(14)
  String? referer;

  DownloadItem({
    required this.animeName,
    required this.animeUrl,
    required this.episodeName,
    required this.episodeUrl,
    required this.sourcePlugin,
    required this.m3u8Url,
    this.cover,
    this.localPath,
    this.status = 0,
    this.progress = 0.0,
    this.totalSegments = 0,
    this.downloadedSegments = 0,
    this.fileSize = 0,
    this.referer,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
}
