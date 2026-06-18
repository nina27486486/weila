// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'danmaku_item.dart';

// **************************************************************************
// TypeAdapter
// **************************************************************************

class DanmakuItemAdapter extends TypeAdapter<DanmakuItem> {
  @override
  final int typeId = 7;

  @override
  DanmakuItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (int i = 0; i < numOfFields; i++) {
      fields[reader.readByte()] = reader.read();
    }
    return DanmakuItem(
      text: fields[0] as String,
      time: fields[1] as double,
      type: fields[2] as int,
      color: fields[3] as int,
      fontSize: fields[4] as int,
    );
  }

  @override
  void write(BinaryWriter writer, DanmakuItem obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)..write(obj.text)
      ..writeByte(1)..write(obj.time)
      ..writeByte(2)..write(obj.type)
      ..writeByte(3)..write(obj.color)
      ..writeByte(4)..write(obj.fontSize);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DanmakuItemAdapter && runtimeType == other.runtimeType && typeId == other.typeId;
}
