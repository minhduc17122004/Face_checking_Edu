part of 'attendance_report_cubit.dart';

class AttendanceReportState {
  final List<CheckInOut> checkInOuts;
  final RequestStatus status;
  final String message;
  final DateTime? filterDate;

  const AttendanceReportState({
    this.checkInOuts = const [],
    this.status = RequestStatus.initial,
    this.message = '',
    this.filterDate,
  });

  AttendanceReportState copyWith({
    List<CheckInOut>? checkInOuts,
    RequestStatus? status,
    String? message,
    DateTime? filterDate,
  }) {
    return AttendanceReportState(
      checkInOuts: checkInOuts ?? this.checkInOuts,
      status: status ?? this.status,
      message: message ?? this.message,
      filterDate: filterDate ?? this.filterDate,
    );
  }
}
