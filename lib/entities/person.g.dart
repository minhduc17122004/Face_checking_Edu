// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'person.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PersonAdapter extends TypeAdapter<Person> {
  @override
  final int typeId = 2;

  @override
  Person read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Person(
      studentId: fields[0] as int,
      updatedTime: fields[1] as DateTime,
      isSynced: fields[2] as bool,
      name: fields[4] as String?,
      pin: fields[3] as String?,
      jobTitle: fields[5] as dynamic,
      avatar: fields[6] as String?,
      serverUserId: fields[7] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Person obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.studentId)
      ..writeByte(1)
      ..write(obj.updatedTime)
      ..writeByte(2)
      ..write(obj.isSynced)
      ..writeByte(3)
      ..write(obj.pin)
      ..writeByte(4)
      ..write(obj.name)
      ..writeByte(5)
      ..write(obj.jobTitle)
      ..writeByte(6)
      ..write(obj.avatar)
      ..writeByte(7)
      ..write(obj.serverUserId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PersonAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
