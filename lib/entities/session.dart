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
  final String? courseName;
  final String? scheduleId;
  final DateTime? sessionDate;
  final DateTime startTime;
  final DateTime? endTime;
  final DateTime? checkinWindowStart;
  final DateTime? checkinWindowEnd;
  final SessionStatus status;
  final int presentCount;
  final int absentCount;
  final int totalCount;
  final DateTime createdAt;

  const Session({
    required this.id,
    required this.courseId,
    this.courseName,
    this.scheduleId,
    this.sessionDate,
    required this.startTime,
    this.endTime,
    this.checkinWindowStart,
    this.checkinWindowEnd,
    this.status = SessionStatus.scheduled,
    this.presentCount = 0,
    this.absentCount = 0,
    this.totalCount = 0,
    required this.createdAt,
  });

  factory Session.fromJson(Map<String, dynamic> json) {
    return Session(
      id: json['id'] as String,
      courseId: json['course_id'] as String,
      courseName: json['course_name'] as String?,
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
      presentCount: json['present_count'] as int? ?? 0,
      absentCount: json['absent_count'] as int? ?? 0,
      totalCount: json['total_count'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'course_id': courseId,
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
    String? courseName,
    String? scheduleId,
    DateTime? sessionDate,
    DateTime? startTime,
    DateTime? endTime,
    DateTime? checkinWindowStart,
    DateTime? checkinWindowEnd,
    SessionStatus? status,
    int? presentCount,
    int? absentCount,
    int? totalCount,
    DateTime? createdAt,
  }) {
    return Session(
      id: id ?? this.id,
      courseId: courseId ?? this.courseId,
      courseName: courseName ?? this.courseName,
      scheduleId: scheduleId ?? this.scheduleId,
      sessionDate: sessionDate ?? this.sessionDate,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      checkinWindowStart: checkinWindowStart ?? this.checkinWindowStart,
      checkinWindowEnd: checkinWindowEnd ?? this.checkinWindowEnd,
      status: status ?? this.status,
      presentCount: presentCount ?? this.presentCount,
      absentCount: absentCount ?? this.absentCount,
      totalCount: totalCount ?? this.totalCount,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  String get formattedDate {
    if (sessionDate == null) return '';
    return '${sessionDate!.day}/${sessionDate!.month}/${sessionDate!.year}';
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
