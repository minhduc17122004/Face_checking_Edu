part of 'attendance_report_cubit.dart';

class AttendanceReportState {
  final List<CheckInOut> checkInOuts;
  final RequestStatus status;
  final String message;
  final DateTime? filterDate;
  final Map<String, String> roomNameById;

  // Sync-specific fields
  final bool isSyncing;
  final String syncMessage;
  final int unsyncedCount; // number of PendingEduCheckIn not yet synced

  const AttendanceReportState({
    this.checkInOuts = const [],
    this.status = RequestStatus.initial,
    this.message = '',
    this.filterDate,
    this.roomNameById = const {},
    this.isSyncing = false,
    this.syncMessage = '',
    this.unsyncedCount = 0,
  });

  AttendanceReportState copyWith({
    List<CheckInOut>? checkInOuts,
    RequestStatus? status,
    String? message,
    DateTime? filterDate,
    Map<String, String>? roomNameById,
    bool? isSyncing,
    String? syncMessage,
    int? unsyncedCount,
  }) {
    return AttendanceReportState(
      checkInOuts: checkInOuts ?? this.checkInOuts,
      status: status ?? this.status,
      message: message ?? this.message,
      filterDate: filterDate ?? this.filterDate,
      roomNameById: roomNameById ?? this.roomNameById,
      isSyncing: isSyncing ?? this.isSyncing,
      syncMessage: syncMessage ?? this.syncMessage,
      unsyncedCount: unsyncedCount ?? this.unsyncedCount,
    );
  }
}
