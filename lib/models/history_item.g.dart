// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'history_item.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class HistoryItemAdapter extends TypeAdapter<HistoryItem> {
  @override
  final typeId = 3;

  @override
  HistoryItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return HistoryItem(
      animeName: fields[0] as String,
      animeUrl: fields[1] as String,
      episodeName: fields[2] as String,
      episodeUrl: fields[3] as String,
      sourcePlugin: fields[4] as String,
      cover: fields[5] as String?,
      position: fields[6] == null ? Duration.zero : fields[6] as Duration,
      duration: fields[7] == null ? Duration.zero : fields[7] as Duration,
      watchedAt: fields[8] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, HistoryItem obj) {
    writer
      ..writeByte(9)
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
      ..write(obj.position)
      ..writeByte(7)
      ..write(obj.duration)
      ..writeByte(8)
      ..write(obj.watchedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HistoryItemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
