import 'package:hive/hive.dart';

part 'pending_edu_check_in.g.dart';

/// Offline queue buffer for EDU face check-ins.
/// Created when the API call fails due to network issues.
/// Background Workmanager retries syncing these to the backend.
@HiveType(typeId: 10)
class PendingEduCheckIn extends HiveObject {
  /// UUID generated client-side for idempotency
  @HiveField(0)
  String localId;

  @HiveField(1)
  int studentId;

  @HiveField(2)
  String? sessionId;

  @HiveField(3)
  DateTime timestamp;

  @HiveField(4)
  String? imagePath;

  @HiveField(5)
  bool isSynced;

  @HiveField(6)
  int retryCount;

  @HiveField(7)
  double? latitude;

  @HiveField(8)
  double? longitude;

  @HiveField(9)
  String? studentName;

  @HiveField(10)
  String? roomId;

  @HiveField(11)
  String? deviceId;

  // UUID from backend
  @HiveField(12)
  String? serverUserId;

  // Student code (MSSV)
  @HiveField(13)
  String? pin;

  @HiveField(14)
  int? minutesLate;

  @HiveField(15)
  String? status;

  @HiveField(16)
  bool isSpoof;

  PendingEduCheckIn({
    required this.localId,
    required this.studentId,
    this.sessionId,
    required this.timestamp,
    this.imagePath,
    this.isSynced = false,
    this.retryCount = 0,
    this.latitude,
    this.longitude,
    this.studentName,
    this.roomId,
    this.deviceId,
    this.serverUserId,
    this.pin,
    this.minutesLate,
    this.status,
    this.isSpoof = false,
  });

  PendingEduCheckIn copyWith({
    String? localId,
    int? studentId,
    String? sessionId,
    DateTime? timestamp,
    String? imagePath,
    bool? isSynced,
    int? retryCount,
    double? latitude,
    double? longitude,
    String? studentName,
    String? roomId,
    String? deviceId,
    String? serverUserId,
    String? pin,
    int? minutesLate,
    String? status,
    bool? isSpoof,
  }) =>
      PendingEduCheckIn(
        localId: localId ?? this.localId,
        studentId: studentId ?? this.studentId,
        sessionId: sessionId ?? this.sessionId,
        timestamp: timestamp ?? this.timestamp,
        imagePath: imagePath ?? this.imagePath,
        isSynced: isSynced ?? this.isSynced,
        retryCount: retryCount ?? this.retryCount,
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
        studentName: studentName ?? this.studentName,
        roomId: roomId ?? this.roomId,
        deviceId: deviceId ?? this.deviceId,
        serverUserId: serverUserId ?? this.serverUserId,
        pin: pin ?? this.pin,
        minutesLate: minutesLate ?? this.minutesLate,
        status: status ?? this.status,
        isSpoof: isSpoof ?? this.isSpoof,
      );
}
