import 'package:face_time_keeping/entities/session.dart';

class RoomSession {
  final String id;
  final String courseId;
  final String courseName;
  final DateTime sessionDate;
  final DateTime startTime;
  final DateTime? endTime;
  final SessionStatus status;
  final int attendanceCount;
  final int totalEnrolled;
  final bool canCheckin;

  const RoomSession({
    required this.id,
    required this.courseId,
    required this.courseName,
    required this.sessionDate,
    required this.startTime,
    this.endTime,
    this.status = SessionStatus.scheduled,
    this.attendanceCount = 0,
    this.totalEnrolled = 0,
    this.canCheckin = false,
  });

  factory RoomSession.fromJson(Map<String, dynamic> json) {
    return RoomSession(
      id: json['id'] as String,
      courseId: json['course_id'] as String,
      courseName: json['course_name'] as String,
      sessionDate: DateTime.parse(json['session_date'] as String),
      startTime: DateTime.parse(json['start_time'] as String),
      endTime: json['end_time'] != null
          ? DateTime.parse(json['end_time'] as String)
          : null,
      status: SessionStatus.fromString(json['status'] as String?),
      attendanceCount: json['attendance_count'] as int? ?? 0,
      totalEnrolled: json['total_enrolled'] as int? ?? 0,
      canCheckin: json['can_checkin'] as bool? ?? false,
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
