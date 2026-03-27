import 'package:hive/hive.dart';

part 'check_in_out.g.dart';

@HiveType(typeId: 0)
class CheckInOut extends HiveObject {
  // for backup database
  int? id;
  @HiveField(0)
  int studentId;
  @HiveField(1) // pin is not a primary key
  String? pin;
  @HiveField(2)
  String name;
  @HiveField(3)
  DateTime time;
  @HiveField(4)
  String? imagePath; //image path
  @HiveField(5)
  bool isSynced;
  @HiveField(6)
  bool isCheckIn;
  @HiveField(7)
  double? latitude;
  @HiveField(8)
  double? longitude;
  @HiveField(9)
  String? roomId;
  @HiveField(10)
  String? deviceId;
  @HiveField(11)
  String? status;
  @HiveField(12)
  int? minutesLate;

  CheckInOut({
    this.id,
    required this.studentId,
    this.pin,
    required this.name,
    required this.time,
    this.imagePath,
    this.isSynced = false,
    this.isCheckIn = true,
    required this.latitude,
    required this.longitude,
    this.roomId,
    this.deviceId,
    this.status,
    this.minutesLate,
  });
  CheckInOut copyWith({
    int? id,
    int? studentId,
    String? pin,
    String? name,
    DateTime? time,
    String? imagePath,
    bool? isSynced,
    bool? isCheckIn,
    double? latitude,
    double? longitude,
    String? roomId,
    String? deviceId,
    String? status,
    int? minutesLate,
  }) =>
      CheckInOut(
          id: id ?? this.id,
          studentId: studentId ?? this.studentId,
          pin: pin ?? this.pin,
          name: name ?? this.name,
          time: time ?? this.time,
          imagePath: imagePath ?? this.imagePath,
          isSynced: isSynced ?? this.isSynced,
          isCheckIn: isCheckIn ?? this.isCheckIn,
          latitude: latitude ?? this.latitude,
          longitude: longitude ?? this.longitude,
          roomId: roomId ?? this.roomId,
          deviceId: deviceId ?? this.deviceId,
          status: status ?? this.status,
          minutesLate: minutesLate ?? this.minutesLate,
      );
  Map<String, dynamic> toSmallJson() {
    if (isCheckIn) {
      return {
        'id': id,
        'in_time': time.toIso8601String().split('.').first,
        'lat': latitude,
        'lon': longitude,
      };
    } else {
      return {
        'id': id,
        'out_time': time.toIso8601String().split('.').first,
        'lat': latitude,
        'lon': longitude,
      };
    }
  }
}
