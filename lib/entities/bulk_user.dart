import 'package:face_time_keeping/entities/check_in_out.dart';

class BulkUser {
  final int employeeId;
  final String? pin;
  final List<CheckInOut> checkInOuts;
  BulkUser({required this.employeeId, this.pin, required this.checkInOuts});
  // Map<String, dynamic> toJson() => {
  //   'pin': pin,
  //   'checkInOuts': checkInOuts.map((e) => e.toJson()).toList(),
  // };
}
