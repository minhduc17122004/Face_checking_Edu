import 'package:face_time_keeping/common/enums/session_attendance_mode.dart';
import 'package:face_time_keeping/entities/session.dart';

class RoomSession {
  final String id;
  final String courseId;
  final String courseName;
  final String? courseCode;
  final String? teacherName;
  final DateTime sessionDate;
  final DateTime startTime;
  final DateTime? endTime;
  final SessionStatus status;
  final String mappedStatus;
  final SessionAttendanceMode? attendanceMode;
  final DateTime? checkinWindowStart;
  final DateTime? checkinWindowEnd;
  final int attendanceCount;
  final int totalEnrolled;
  final bool canCheckin;
  final bool canOpen;
  final bool canClose;

  final bool isClosedEarly;

  const RoomSession({
    required this.id,
    required this.courseId,
    required this.courseName,
    this.courseCode,
    this.teacherName,
    required this.sessionDate,
    required this.startTime,
    this.endTime,
    this.status = SessionStatus.scheduled,
    this.mappedStatus = 'NOT_OPEN',
    this.attendanceMode,
    this.checkinWindowStart,
    this.checkinWindowEnd,
    this.attendanceCount = 0,
    this.totalEnrolled = 0,
    this.canCheckin = false,
    this.canOpen = false,
    this.canClose = false,
    this.isClosedEarly = false,
  });

  factory RoomSession.fromJson(Map<String, dynamic> json) {
    return RoomSession(
      id: json['id'] as String,
      courseId: json['course_id'] as String,
      courseName: json['course_name'] as String,
      courseCode: json['course_code'] as String?,
      teacherName: json['teacher_name'] as String?,
      sessionDate: DateTime.parse(json['session_date'] as String),
      startTime: DateTime.parse(json['start_time'] as String),
      endTime: json['end_time'] != null
          ? DateTime.parse(json['end_time'] as String)
          : null,
      status: SessionStatus.fromString(json['status'] as String?),
      mappedStatus: (json['mapped_status'] as String?) ?? (json['status_label'] as String?) ?? 'NOT_OPEN',
      attendanceMode: SessionAttendanceModeX.fromString(
          json['mode'] as String? ?? json['attendance_mode'] as String?),
      checkinWindowStart: json['checkin_window_start'] != null
          ? DateTime.parse(json['checkin_window_start'] as String)
          : null,
      checkinWindowEnd: json['checkin_window_end'] != null
          ? DateTime.parse(json['checkin_window_end'] as String)
          : null,
      attendanceCount: json['attendance_count'] as int? ?? 0,
      totalEnrolled: json['total_enrolled'] as int? ?? 0,
      canCheckin: json['can_checkin'] as bool? ?? false,
      canOpen: json['can_open'] as bool? ?? false,
      canClose: json['can_close'] as bool? ?? false,
      isClosedEarly: json['is_closed_early'] as bool? ?? false,
    );
  }

  int get absentCount => totalEnrolled - attendanceCount;

  double get attendanceRate {
    if (totalEnrolled == 0) return 0.0;
    return (attendanceCount / totalEnrolled) * 100;
  }

  bool get isActive => status == SessionStatus.active;
  bool get isScheduled => status == SessionStatus.scheduled;
  bool get isClosed => status == SessionStatus.closed;

  String get formattedDate {
    return '${sessionDate.day}/${sessionDate.month}/${sessionDate.year}';
  }

  String get formattedStartTime {
    return '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}';
  }

  String get formattedEndTime {
    if (endTime == null) return '';
    return '${endTime!.hour.toString().padLeft(2, '0')}:${endTime!.minute.toString().padLeft(2, '0')}';
  }

  @override
  String toString() =>
      'RoomSession(id: $id, course: $courseName, status: ${status.value})';
}
