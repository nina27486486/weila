// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'danmaku_item.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DanmakuItemAdapter extends TypeAdapter<DanmakuItem> {
  @override
  final typeId = 7;

  @override
  DanmakuItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DanmakuItem(
      text: fields[0] as String,
      time: (fields[1] as num).toDouble(),
      type: fields[2] == null ? 0 : (fields[2] as num).toInt(),
      color: fields[3] == null ? 0xFFFFFFFF : (fields[3] as num).toInt(),
      fontSize: fields[4] == null ? 16 : (fields[4] as num).toInt(),
    );
  }

  @override
  void write(BinaryWriter writer, DanmakuItem obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.text)
      ..writeByte(1)
      ..write(obj.time)
      ..writeByte(2)
      ..write(obj.type)
      ..writeByte(3)
      ..write(obj.color)
      ..writeByte(4)
      ..write(obj.fontSize);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DanmakuItemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
