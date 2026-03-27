import 'package:face_time_keeping/entities/student.dart';
import 'package:hive/hive.dart';

part 'person.g.dart';

@HiveType(typeId: 2)
class Person extends HiveObject {
  @HiveField(0)
  final int studentId;

  @HiveField(1)
  final DateTime updatedTime;

  @HiveField(2)
  final bool isSynced;

  @HiveField(3)
  final String? pin;
  @HiveField(4)
  final String? name;
  @HiveField(5)
  final dynamic jobTitle;
  @HiveField(6)
  final String? avatar;

  /// UUID from backend (e.g. "19c0116c-3b56-484e-a567-e0289afcf8a0").
  /// Used to identify the student when syncing PendingEduCheckIn to the backend.
  @HiveField(7)
  final String? serverUserId;

  Person({
    required this.studentId,
    required this.updatedTime,
    this.isSynced = false,
    required this.name,
    this.pin,
    this.jobTitle,
    this.avatar,
    this.serverUserId,
  });

  Person copyWith({
    int? studentId,
    DateTime? updatedTime,
    bool? isSynced,
    String? name,
    String? pin,
    dynamic jobTitle,
    String? avatar,
    String? serverUserId,
  }) {
    return Person(
      studentId: studentId ?? this.studentId,
      updatedTime: updatedTime ?? this.updatedTime,
      isSynced: isSynced ?? this.isSynced,
      name: name ?? this.name,
      pin: pin ?? this.pin,
      jobTitle: jobTitle ?? this.jobTitle,
      avatar: avatar ?? this.avatar,
      serverUserId: serverUserId ?? this.serverUserId,
    );
  }

  Student toStudent() {
    return Student(
      id: studentId,
      pin: pin,
      name: name ?? '',
      jobTitle: jobTitle,
      avatar: avatar,
      serverUserId: serverUserId,
    );
  }

  @override
  String toString() {
    return 'Person(studentId: $studentId, serverUserId: $serverUserId, updatedTime: $updatedTime, isSynced: $isSynced)';
  }
}
