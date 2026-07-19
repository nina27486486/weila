// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'track_item.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TrackItemAdapter extends TypeAdapter<TrackItem> {
  @override
  final typeId = 5;

  @override
  TrackItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TrackItem(
      animeName: fields[0] as String,
      animeUrl: fields[1] as String,
      sourcePlugin: fields[2] as String,
      cover: fields[3] as String?,
      status: fields[4] as String?,
      totalEpisodes: fields[5] == null ? 0 : (fields[5] as num).toInt(),
      watchedEpisodes: fields[6] == null ? 0 : (fields[6] as num).toInt(),
      trackedAt: fields[7] as DateTime?,
      lastUpdated: fields[8] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, TrackItem obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.animeName)
      ..writeByte(1)
      ..write(obj.animeUrl)
      ..writeByte(2)
      ..write(obj.sourcePlugin)
      ..writeByte(3)
      ..write(obj.cover)
      ..writeByte(4)
      ..write(obj.status)
      ..writeByte(5)
      ..write(obj.totalEpisodes)
      ..writeByte(6)
      ..write(obj.watchedEpisodes)
      ..writeByte(7)
      ..write(obj.trackedAt)
      ..writeByte(8)
      ..write(obj.lastUpdated);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TrackItemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
