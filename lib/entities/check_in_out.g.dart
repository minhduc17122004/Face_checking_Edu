// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'check_in_out.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CheckInOutAdapter extends TypeAdapter<CheckInOut> {
  @override
  final int typeId = 0;

  @override
  CheckInOut read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CheckInOut(
      studentId: fields[0] as int,
      pin: fields[1] as String?,
      name: fields[2] as String,
      time: fields[3] as DateTime,
      imagePath: fields[4] as String?,
      isSynced: fields[5] as bool,
      isCheckIn: fields[6] as bool,
      latitude: fields[7] as double?,
      longitude: fields[8] as double?,
      roomId: fields[9] as String?,
      deviceId: fields[10] as String?,
      status: fields[11] as String?,
      minutesLate: fields[12] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, CheckInOut obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.studentId)
      ..writeByte(1)
      ..write(obj.pin)
      ..writeByte(2)
      ..write(obj.name)
      ..writeByte(3)
      ..write(obj.time)
      ..writeByte(4)
      ..write(obj.imagePath)
      ..writeByte(5)
      ..write(obj.isSynced)
      ..writeByte(6)
      ..write(obj.isCheckIn)
      ..writeByte(7)
      ..write(obj.latitude)
      ..writeByte(8)
      ..write(obj.longitude)
      ..writeByte(9)
      ..write(obj.roomId)
      ..writeByte(10)
      ..write(obj.deviceId)
      ..writeByte(11)
      ..write(obj.status)
      ..writeByte(12)
      ..write(obj.minutesLate);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CheckInOutAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
