// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'download_item.dart';

class DownloadItemAdapter extends TypeAdapter<DownloadItem> {
  @override
  final int typeId = 6;

  @override
  DownloadItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (int i = 0; i < numOfFields; i++) {
      fields[reader.readByte()] = reader.read();
    }
    return DownloadItem(
      animeName: fields[0] as String,
      animeUrl: fields[1] as String,
      episodeName: fields[2] as String,
      episodeUrl: fields[3] as String,
      sourcePlugin: fields[4] as String,
      cover: fields[5] as String?,
      localPath: fields[6] as String?,
      status: fields[7] as int,
      progress: fields[8] as double,
      totalSegments: fields[9] as int,
      downloadedSegments: fields[10] as int,
      createdAt: fields[11] as DateTime?,
      fileSize: fields[12] as int,
      m3u8Url: fields[13] as String,
      referer: fields[14] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, DownloadItem obj) {
    writer
      ..writeByte(15)
      ..writeByte(0)..write(obj.animeName)
      ..writeByte(1)..write(obj.animeUrl)
      ..writeByte(2)..write(obj.episodeName)
      ..writeByte(3)..write(obj.episodeUrl)
      ..writeByte(4)..write(obj.sourcePlugin)
      ..writeByte(5)..write(obj.cover)
      ..writeByte(6)..write(obj.localPath)
      ..writeByte(7)..write(obj.status)
      ..writeByte(8)..write(obj.progress)
      ..writeByte(9)..write(obj.totalSegments)
      ..writeByte(10)..write(obj.downloadedSegments)
      ..writeByte(11)..write(obj.createdAt)
      ..writeByte(12)..write(obj.fileSize)
      ..writeByte(13)..write(obj.m3u8Url)
      ..writeByte(14)..write(obj.referer);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DownloadItemAdapter && runtimeType == other.runtimeType && typeId == other.typeId;
}
