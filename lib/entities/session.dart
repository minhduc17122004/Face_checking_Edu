import 'package:face_time_keeping/common/enums/session_attendance_mode.dart';

enum SessionStatus {
  scheduled,
  active,
  closed;

  String get value {
    switch (this) {
      case SessionStatus.scheduled:
        return 'scheduled';
      case SessionStatus.active:
        return 'active';
      case SessionStatus.closed:
        return 'closed';
    }
  }

  String get label {
    switch (this) {
      case SessionStatus.scheduled:
        return 'Đã lên lịch';
      case SessionStatus.active:
        return 'Đang diễn ra';
      case SessionStatus.closed:
        return 'Đã kết thúc';
    }
  }

  static SessionStatus fromString(String? value) {
    switch (value) {
      case 'active':
        return SessionStatus.active;
      case 'closed':
        return SessionStatus.closed;
      default:
        return SessionStatus.scheduled;
    }
  }
}

class Session {
  final String id;
  final String courseId;
  final String? courseCode;
  final String? courseName;
  final String? teacherName;
  final String? roomName;
  final String? timeSlotName;
  final int? dayOfWeek;
  final String? scheduleId;
  final DateTime? sessionDate;
  final DateTime startTime;
  final DateTime? endTime;
  final DateTime? checkinWindowStart;
  final DateTime? checkinWindowEnd;
  final SessionStatus status;
  final String? mappedStatus;
  final SessionAttendanceMode? attendanceMode;
  final bool canOpen;
  final bool canClose;
  final int presentCount;
  final int absentCount;
  final int totalCount;
  final int enrolledCount;
  final DateTime createdAt;

  const Session({
    required this.id,
    required this.courseId,
    this.courseCode,
    this.courseName,
    this.teacherName,
    this.roomName,
    this.timeSlotName,
    this.dayOfWeek,
    this.scheduleId,
    this.sessionDate,
    required this.startTime,
    this.endTime,
    this.checkinWindowStart,
    this.checkinWindowEnd,
    this.status = SessionStatus.scheduled,
    this.mappedStatus,
    this.attendanceMode,
    this.canOpen = false,
    this.canClose = false,
    this.presentCount = 0,
    this.absentCount = 0,
    this.totalCount = 0,
    this.enrolledCount = 0,
    required this.createdAt,
  });

  factory Session.fromJson(Map<String, dynamic> json) {
    return Session(
      id: json['id'] as String,
      courseId: json['course_id'] as String,
      courseCode: json['course_code'] as String?,
      courseName: json['course_name'] as String?,
      teacherName: json['teacher_name'] as String?,
      roomName: json['room_name'] as String?,
      timeSlotName: json['time_slot_name'] as String?,
      dayOfWeek: json['day_of_week'] as int?,
      scheduleId: json['schedule_id'] as String?,
      sessionDate: json['session_date'] != null
          ? DateTime.parse(json['session_date'] as String)
          : null,
      startTime: DateTime.parse(json['start_time'] as String),
      endTime: json['end_time'] != null
          ? DateTime.parse(json['end_time'] as String)
          : null,
      checkinWindowStart: json['checkin_window_start'] != null
          ? DateTime.parse(json['checkin_window_start'] as String)
          : null,
      checkinWindowEnd: json['checkin_window_end'] != null
          ? DateTime.parse(json['checkin_window_end'] as String)
          : null,
      status: SessionStatus.fromString(json['status'] as String?),
      mappedStatus: json['mapped_status'] as String?,
      attendanceMode: SessionAttendanceModeX.fromString(
          json['mode'] as String? ?? json['attendance_mode'] as String?),
      canOpen: json['can_open'] as bool? ?? false,
      canClose: json['can_close'] as bool? ?? false,
      presentCount: json['present_count'] as int? ?? 0,
      absentCount: json['absent_count'] as int? ?? 0,
      totalCount: json['total_count'] as int? ?? 0,
      enrolledCount: json['enrolled_count'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'course_id': courseId,
      'course_code': courseCode,
      'schedule_id': scheduleId,
      'session_date':
          sessionDate != null ? _dateToIso(sessionDate!) : null,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime?.toIso8601String(),
      'checkin_window_start': checkinWindowStart?.toIso8601String(),
      'checkin_window_end': checkinWindowEnd?.toIso8601String(),
      'status': status.value,
    };
  }

  static String _dateToIso(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  Session copyWith({
    String? id,
    String? courseId,
    String? courseCode,
    String? courseName,
    String? teacherName,
    String? roomName,
    String? timeSlotName,
    int? dayOfWeek,
    String? scheduleId,
    DateTime? sessionDate,
    DateTime? startTime,
    DateTime? endTime,
    DateTime? checkinWindowStart,
    DateTime? checkinWindowEnd,
    SessionStatus? status,
    String? mappedStatus,
    SessionAttendanceMode? attendanceMode,
    bool? canOpen,
    bool? canClose,
    int? presentCount,
    int? absentCount,
    int? totalCount,
    int? enrolledCount,
    DateTime? createdAt,
  }) {
    return Session(
      id: id ?? this.id,
      courseId: courseId ?? this.courseId,
      courseCode: courseCode ?? this.courseCode,
      courseName: courseName ?? this.courseName,
      teacherName: teacherName ?? this.teacherName,
      roomName: roomName ?? this.roomName,
      timeSlotName: timeSlotName ?? this.timeSlotName,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      scheduleId: scheduleId ?? this.scheduleId,
      sessionDate: sessionDate ?? this.sessionDate,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      checkinWindowStart: checkinWindowStart ?? this.checkinWindowStart,
      checkinWindowEnd: checkinWindowEnd ?? this.checkinWindowEnd,
      status: status ?? this.status,
      mappedStatus: mappedStatus ?? this.mappedStatus,
      attendanceMode: attendanceMode ?? this.attendanceMode,
      canOpen: canOpen ?? this.canOpen,
      canClose: canClose ?? this.canClose,
      presentCount: presentCount ?? this.presentCount,
      absentCount: absentCount ?? this.absentCount,
      totalCount: totalCount ?? this.totalCount,
      enrolledCount: enrolledCount ?? this.enrolledCount,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  String get formattedDate {
    if (sessionDate == null) return '';
    return '${sessionDate!.day}/${sessionDate!.month}/${sessionDate!.year}';
  }

  String get formattedStartTime {
    final localTime = startTime.toLocal();
    return '${localTime.hour.toString().padLeft(2, '0')}:${localTime.minute.toString().padLeft(2, '0')}';
  }

  String get formattedEndTime {
    if (endTime == null) return '';
    final localTime = endTime!.toLocal();
    return '${localTime.hour.toString().padLeft(2, '0')}:${localTime.minute.toString().padLeft(2, '0')}';
  }

  String get formattedCheckinWindow {
    String fmt(DateTime dt) {
      final l = dt.toLocal();
      return '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
    }
    final start = checkinWindowStart ?? startTime;
    final end   = checkinWindowEnd   ?? endTime;
    if (end == null) return fmt(start);
    return '${fmt(start)} - ${fmt(end)}';
  }

  @override
  String toString() =>
      'Session(id: $id, courseId: $courseId, status: ${status.value})';
}

class SessionSummary {
  final String sessionId;
  final int totalEnrolled;
  final int presentCount;
  final int absentCount;
  final int lateCount;
  final double? attendanceRate;

  const SessionSummary({
    required this.sessionId,
    this.totalEnrolled = 0,
    this.presentCount = 0,
    this.absentCount = 0,
    this.lateCount = 0,
    this.attendanceRate,
  });

  factory SessionSummary.fromJson(Map<String, dynamic> json) {
    return SessionSummary(
      sessionId: (json['session_id'] as String?) ?? '',
      totalEnrolled: json['total_students'] as int? ?? 0,
      presentCount: json['present'] as int? ?? 0,
      absentCount: json['absent'] as int? ?? 0,
      lateCount: json['late'] as int? ?? 0,
      attendanceRate: (json['attendance_rate'] as num?)?.toDouble(),
    );
  }
}
