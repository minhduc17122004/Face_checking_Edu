import 'package:face_time_keeping/entities/check_in_out.dart';

class BulkUser {
  final int studentId;
  final String? pin;
  final List<CheckInOut> checkInOuts;
  BulkUser({required this.studentId, this.pin, required this.checkInOuts});
}
