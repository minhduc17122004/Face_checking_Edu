// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pending_edu_check_in.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PendingEduCheckInAdapter extends TypeAdapter<PendingEduCheckIn> {
  @override
  final int typeId = 10;

  @override
  PendingEduCheckIn read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PendingEduCheckIn(
      localId: fields[0] as String,
      studentId: fields[1] as int,
      sessionId: fields[2] as String?,
      timestamp: fields[3] as DateTime,
      imagePath: fields[4] as String?,
      isSynced: fields[5] as bool,
      retryCount: fields[6] as int,
      latitude: fields[7] as double?,
      longitude: fields[8] as double?,
      studentName: fields[9] as String?,
      roomId: fields[10] as String?,
      deviceId: fields[11] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, PendingEduCheckIn obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.localId)
      ..writeByte(1)
      ..write(obj.studentId)
      ..writeByte(2)
      ..write(obj.sessionId)
      ..writeByte(3)
      ..write(obj.timestamp)
      ..writeByte(4)
      ..write(obj.imagePath)
      ..writeByte(5)
      ..write(obj.isSynced)
      ..writeByte(6)
      ..write(obj.retryCount)
      ..writeByte(7)
      ..write(obj.latitude)
      ..writeByte(8)
      ..write(obj.longitude)
      ..writeByte(9)
      ..write(obj.studentName)
      ..writeByte(10)
      ..write(obj.roomId)
      ..writeByte(11)
      ..write(obj.deviceId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PendingEduCheckInAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
