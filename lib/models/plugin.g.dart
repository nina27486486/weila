// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'plugin.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PluginAdapter extends TypeAdapter<Plugin> {
  @override
  final typeId = 0;

  @override
  Plugin read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Plugin(
      api: fields[0] as String,
      name: fields[1] as String,
      version: fields[2] == null ? '1.0.0' : fields[2] as String,
      baseUrl: fields[3] as String,
      searchURL: fields[4] as String,
      searchList: fields[5] as String,
      searchName: fields[6] as String,
      searchResult: fields[7] as String,
      chapterRoads: fields[8] as String,
      chapterResult: fields[9] as String,
      userAgent: fields[10] == null ? '' : fields[10] as String,
      referer: fields[11] as String?,
      enabled: fields[12] == null ? true : fields[12] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, Plugin obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.api)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.version)
      ..writeByte(3)
      ..write(obj.baseUrl)
      ..writeByte(4)
      ..write(obj.searchURL)
      ..writeByte(5)
      ..write(obj.searchList)
      ..writeByte(6)
      ..write(obj.searchName)
      ..writeByte(7)
      ..write(obj.searchResult)
      ..writeByte(8)
      ..write(obj.chapterRoads)
      ..writeByte(9)
      ..write(obj.chapterResult)
      ..writeByte(10)
      ..write(obj.userAgent)
      ..writeByte(11)
      ..write(obj.referer)
      ..writeByte(12)
      ..write(obj.enabled);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PluginAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
