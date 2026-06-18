// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'collect_item.dart';

class CollectItemAdapter extends TypeAdapter<CollectItem> {
  @override
  final int typeId = 4;

  @override
  CollectItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (int i = 0; i < numOfFields; i++) {
      fields[reader.readByte()] = reader.read();
    }
    return CollectItem(
      animeName: fields[0] as String,
      animeUrl: fields[1] as String,
      sourcePlugin: fields[2] as String,
      cover: fields[3] as String?,
      description: fields[4] as String?,
      collectedAt: fields[5] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, CollectItem obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)..write(obj.animeName)
      ..writeByte(1)..write(obj.animeUrl)
      ..writeByte(2)..write(obj.sourcePlugin)
      ..writeByte(3)..write(obj.cover)
      ..writeByte(4)..write(obj.description)
      ..writeByte(5)..write(obj.collectedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CollectItemAdapter && runtimeType == other.runtimeType && typeId == other.typeId;
}
