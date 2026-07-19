// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'download_item.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DownloadItemAdapter extends TypeAdapter<DownloadItem> {
  @override
  final typeId = 6;

  @override
  DownloadItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DownloadItem(
      animeName: fields[0] as String,
      animeUrl: fields[1] as String,
      episodeName: fields[2] as String,
      episodeUrl: fields[3] as String,
      sourcePlugin: fields[4] as String,
      m3u8Url: fields[13] as String,
      cover: fields[5] as String?,
      localPath: fields[6] as String?,
      status: fields[7] == null ? 0 : (fields[7] as num).toInt(),
      progress: fields[8] == null ? 0.0 : (fields[8] as num).toDouble(),
      totalSegments: fields[9] == null ? 0 : (fields[9] as num).toInt(),
      downloadedSegments: fields[10] == null ? 0 : (fields[10] as num).toInt(),
      fileSize: fields[12] == null ? 0 : (fields[12] as num).toInt(),
      referer: fields[14] as String?,
      createdAt: fields[11] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, DownloadItem obj) {
    writer
      ..writeByte(15)
      ..writeByte(0)
      ..write(obj.animeName)
      ..writeByte(1)
      ..write(obj.animeUrl)
      ..writeByte(2)
      ..write(obj.episodeName)
      ..writeByte(3)
      ..write(obj.episodeUrl)
      ..writeByte(4)
      ..write(obj.sourcePlugin)
      ..writeByte(5)
      ..write(obj.cover)
      ..writeByte(6)
      ..write(obj.localPath)
      ..writeByte(7)
      ..write(obj.status)
      ..writeByte(8)
      ..write(obj.progress)
      ..writeByte(9)
      ..write(obj.totalSegments)
      ..writeByte(10)
      ..write(obj.downloadedSegments)
      ..writeByte(11)
      ..write(obj.createdAt)
      ..writeByte(12)
      ..write(obj.fileSize)
      ..writeByte(13)
      ..write(obj.m3u8Url)
      ..writeByte(14)
      ..write(obj.referer);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DownloadItemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
