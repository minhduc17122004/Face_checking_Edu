import 'package:hive/hive.dart';

part 'check_in_out.g.dart';

@HiveType(typeId: 0)
class CheckInOut extends HiveObject {
  // for backup database
  int? id;
  @HiveField(0)
  int employeeId;
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

  CheckInOut({
    this.id,
    required this.employeeId,
    this.pin,
    required this.name,
    required this.time,
    this.imagePath,
    this.isSynced = false,
    this.isCheckIn = true,
    required this.latitude,
    required this.longitude,
  });
  CheckInOut copyWith({
    int? id,
    int? employeeId,
    String? pin,
    String? name,
    DateTime? time,
    String? imagePath,
    bool? isSynced,
    bool? isCheckIn,
    double? latitude,
    double? longitude,
  }) =>
      CheckInOut(
          id: id ?? this.id,
          employeeId: employeeId ?? this.employeeId,
          pin: pin ?? this.pin,
          name: name ?? this.name,
          time: time ?? this.time,
          imagePath: imagePath ?? this.imagePath,
          isSynced: isSynced ?? this.isSynced,
          isCheckIn: isCheckIn ?? this.isCheckIn,
          latitude: latitude ?? this.latitude,
          longitude: longitude ?? this.longitude);
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
