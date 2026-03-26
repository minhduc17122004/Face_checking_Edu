import 'package:face_time_keeping/common/enums/request_status.dart';
import 'package:face_time_keeping/data/remote/attendance_checkin_service.dart';
import 'package:face_time_keeping/entities/attendance_record_ui.dart';

class AttendanceCheckinState {
  final RequestStatus requestStatus;
  final List<AttendanceRecordUI> records;
  final AttendanceCheckinSummary? summary;
  final ManualCheckinResult? lastCheckin;
  final String? message;

  AttendanceCheckinState({
    this.requestStatus = RequestStatus.initial,
    this.records = const [],
    this.summary,
    this.lastCheckin,
    this.message,
  });

  AttendanceCheckinState copyWith({
    RequestStatus? requestStatus,
    List<AttendanceRecordUI>? records,
    AttendanceCheckinSummary? summary,
    ManualCheckinResult? lastCheckin,
    String? message,
  }) {
    return AttendanceCheckinState(
      requestStatus: requestStatus ?? this.requestStatus,
      records: records ?? this.records,
      summary: summary ?? this.summary,
      lastCheckin: lastCheckin ?? this.lastCheckin,
      message: message,
    );
  }

  int get totalCount => records.length;
  int get presentCount => records.where((r) => r.isPresent).length;
  int get lateCount => records.where((r) => r.isLate).length;
}
