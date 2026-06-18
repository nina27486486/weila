// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'anime.dart';

class AnimeAdapter extends TypeAdapter<Anime> {
  @override
  final int typeId = 1;

  @override
  Anime read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (int i = 0; i < numOfFields; i++) {
      fields[reader.readByte()] = reader.read();
    }
    return Anime(
      name: fields[0] as String,
      url: fields[1] as String,
      cover: fields[2] as String?,
      description: fields[3] as String?,
      sourcePlugin: fields[4] as String,
      episodes: (fields[5] as List).cast<Episode>(),
    );
  }

  @override
  void write(BinaryWriter writer, Anime obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)..write(obj.name)
      ..writeByte(1)..write(obj.url)
      ..writeByte(2)..write(obj.cover)
      ..writeByte(3)..write(obj.description)
      ..writeByte(4)..write(obj.sourcePlugin)
      ..writeByte(5)..write(obj.episodes);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AnimeAdapter && runtimeType == other.runtimeType && typeId == other.typeId;
}

class EpisodeAdapter extends TypeAdapter<Episode> {
  @override
  final int typeId = 2;

  @override
  Episode read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (int i = 0; i < numOfFields; i++) {
      fields[reader.readByte()] = reader.read();
    }
    return Episode(
      name: fields[0] as String,
      url: fields[1] as String,
      index: fields[2] as int,
    );
  }

  @override
  void write(BinaryWriter writer, Episode obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)..write(obj.name)
      ..writeByte(1)..write(obj.url)
      ..writeByte(2)..write(obj.index);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EpisodeAdapter && runtimeType == other.runtimeType && typeId == other.typeId;
}
