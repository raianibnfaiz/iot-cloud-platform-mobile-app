// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'widget.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PinConfigAdapter extends TypeAdapter<PinConfig> {
  @override
  final int typeId = 1;

  @override
  PinConfig read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PinConfig(
      virtualPin: fields[0] as int,
      value: fields[1] as int,
      id: fields[2] as String,
    );
  }

  @override
  void write(BinaryWriter writer, PinConfig obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.virtualPin)
      ..writeByte(1)
      ..write(obj.value)
      ..writeByte(2)
      ..write(obj.id);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PinConfigAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class PositionAdapter extends TypeAdapter<Position> {
  @override
  final int typeId = 3;

  @override
  Position read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Position(
      x: fields[0] as double,
      y: fields[1] as double,
    );
  }

  @override
  void write(BinaryWriter writer, Position obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.x)
      ..writeByte(1)
      ..write(obj.y);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PositionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class WidgetAdapter extends TypeAdapter<Widget> {
  @override
  final int typeId = 2;

  @override
  Widget read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Widget(
      id: fields[0] as String,
      name: fields[1] as String,
      image: fields[2] as String,
      pinRequired: fields[3] as int,
      pinConfig: (fields[4] as List).cast<PinConfig>(),
      position: fields[5] as Position?,
      configuration: (fields[6] as Map?)?.cast<String, dynamic>(),
    );
  }

  @override
  void write(BinaryWriter writer, Widget obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.image)
      ..writeByte(3)
      ..write(obj.pinRequired)
      ..writeByte(4)
      ..write(obj.pinConfig)
      ..writeByte(5)
      ..write(obj.position)
      ..writeByte(6)
      ..write(obj.configuration);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WidgetAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
