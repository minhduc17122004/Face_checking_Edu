import 'package:face_time_keeping/common/enums/request_status.dart';
import 'package:face_time_keeping/data/remote/attendance_checkin_service.dart';
import 'package:face_time_keeping/entities/attendance_record_ui.dart';
import 'package:face_time_keeping/entities/edu_check_in.dart';

class EduCheckingState {
  final RequestStatus faceStatus;
  final RequestStatus checkinStatus;
  final String? errorMessage;
  final EduCheckIn? lastCheckIn;
  final bool isAllowCapture;

  /// True when check-in was saved locally (offline fallback)
  final bool isOfflineMode;

  /// True when there are pending items waiting to be synced
  final bool hasPendingSync;

  final List<AttendanceRecordUI> sessionRecords;
  final AttendanceCheckinSummary? summary;

  const EduCheckingState({
    this.faceStatus = RequestStatus.initial,
    this.checkinStatus = RequestStatus.initial,
    this.errorMessage,
    this.lastCheckIn,
    this.isAllowCapture = true,
    this.isOfflineMode = false,
    this.hasPendingSync = false,
    this.sessionRecords = const [],
    this.summary,
  });

  EduCheckingState copyWith({
    RequestStatus? faceStatus,
    RequestStatus? checkinStatus,
    String? errorMessage,
    EduCheckIn? lastCheckIn,
    bool? isAllowCapture,
    bool? isOfflineMode,
    bool? hasPendingSync,
    List<AttendanceRecordUI>? sessionRecords,
    AttendanceCheckinSummary? summary,
    bool clearError = false,
    bool clearLastCheckIn = false,
  }) {
    return EduCheckingState(
      faceStatus: faceStatus ?? this.faceStatus,
      checkinStatus: checkinStatus ?? this.checkinStatus,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      lastCheckIn:
          clearLastCheckIn ? null : lastCheckIn ?? this.lastCheckIn,
      isAllowCapture: isAllowCapture ?? this.isAllowCapture,
      isOfflineMode: isOfflineMode ?? this.isOfflineMode,
      hasPendingSync: hasPendingSync ?? this.hasPendingSync,
      sessionRecords: sessionRecords ?? this.sessionRecords,
      summary: summary ?? this.summary,
    );
  }

  EduCheckingState refreshCapture() {
    return copyWith(
      faceStatus: RequestStatus.initial,
      checkinStatus: RequestStatus.initial,
      isAllowCapture: true,
      clearError: true,
      clearLastCheckIn: true,
      isOfflineMode: false,
    );
  }
}
