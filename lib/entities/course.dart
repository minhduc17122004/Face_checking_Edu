enum AttendanceMode {
  preset,
  flexible,
  custom;

  String get value {
    switch (this) {
      case AttendanceMode.preset:
        return 'preset';
      case AttendanceMode.flexible:
        return 'flexible';
      case AttendanceMode.custom:
        return 'custom';
    }
  }

  String get label {
    switch (this) {
      case AttendanceMode.preset:
        return 'Tự động mở/đóng theo thời gian tiết học';
      case AttendanceMode.flexible:
        return 'Giáo viên đóng mở thủ công khi tiết đang diễn ra';
      case AttendanceMode.custom:
        return 'Mở/đóng theo khoảng thời gian tự thiết lập (trong tiết học)';
    }
  }

  String get shortLabel {
    switch (this) {
      case AttendanceMode.preset:
        return 'Cố định';
      case AttendanceMode.flexible:
        return 'Linh hoạt';
      case AttendanceMode.custom:
        return 'Tự thiết lập';
    }
  }

  static AttendanceMode fromString(String? value) {
    switch (value) {
      case 'flexible':
        return AttendanceMode.flexible;
      case 'custom':
        return AttendanceMode.custom;
      default:
        return AttendanceMode.preset;
    }
  }
}

class Course {
  final String id;
  final String courseName;
  final String? courseCode;
  final int? teacherId;
  final String? teacherName;
  final String? departmentId;
  final String? departmentName;
  final String? roomId;
  final String? roomName;
  final AttendanceMode attendanceMode;
  final int customWindowStartMinutes;
  final int customWindowEndMinutes;
  final int enrolledCount;
  final int? dayOfWeek;
  final int? timeSlotId;
  final String? timeSlotName;
  final int? totalSessions;
  final int? credits;
  final bool isCourseActiveNow;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const Course({
    required this.id,
    required this.courseName,
    this.courseCode,
    this.teacherId,
    this.teacherName,
    this.departmentId,
    this.departmentName,
    this.roomId,
    this.roomName,
    this.attendanceMode = AttendanceMode.preset,
    this.customWindowStartMinutes = 0,
    this.customWindowEndMinutes = 30,
    this.enrolledCount = 0,
    this.dayOfWeek,
    this.timeSlotId,
    this.timeSlotName,
    this.totalSessions,
    this.credits,
    this.isCourseActiveNow = true,
    required this.createdAt,
    this.updatedAt,
  });

  factory Course.fromJson(Map<String, dynamic> json) {
    return Course(
      id: json['id'] as String,
      courseName: json['course_name'] as String,
      courseCode: json['course_code'] as String?,
      teacherId: json['teacher_id'] as int?,
      teacherName: json['teacher_name'] as String?,
      departmentId: json['department_id'] as String?,
      departmentName: json['department_name'] as String?,
      roomId: json['room_id'] as String?,
      roomName: json['room_name'] as String?,
      attendanceMode: AttendanceMode.fromString(
          json['attendance_mode'] as String? ?? 'preset'),
      customWindowStartMinutes:
          json['custom_window_start_minutes'] as int? ?? 0,
      customWindowEndMinutes:
          json['custom_window_end_minutes'] as int? ?? 30,
      enrolledCount: json['enrolled_count'] as int? ?? 0,
      dayOfWeek: json['day_of_week'] as int?,
      timeSlotId: json['time_slot_id'] as int?,
      timeSlotName: json['time_slot_name'] as String?,
      totalSessions: json['total_sessions'] as int?,
      credits: json['credits'] as int?,
      isCourseActiveNow: json['is_course_active_now'] ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'course_name': courseName,
      'course_code': courseCode,
      'teacher_id': teacherId,
      'department_id': departmentId,
      'room_id': roomId,
      'attendance_mode': attendanceMode.value,
      'custom_window_start_minutes': customWindowStartMinutes,
      'custom_window_end_minutes': customWindowEndMinutes,
      'day_of_week': dayOfWeek,
      'time_slot_id': timeSlotId,
      if (totalSessions != null) 'total_sessions': totalSessions,
      if (credits != null) 'credits': credits,
    };
  }

  Course copyWith({
    String? id,
    String? courseName,
    String? courseCode,
    int? teacherId,
    String? teacherName,
    String? departmentId,
    String? departmentName,
    String? roomId,
    String? roomName,
    AttendanceMode? attendanceMode,
    int? customWindowStartMinutes,
    int? customWindowEndMinutes,
    int? enrolledCount,
    int? dayOfWeek,
    int? timeSlotId,
    String? timeSlotName,
    int? totalSessions,
    int? credits,
    bool? isCourseActiveNow,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Course(
      id: id ?? this.id,
      courseName: courseName ?? this.courseName,
      courseCode: courseCode ?? this.courseCode,
      teacherId: teacherId ?? this.teacherId,
      teacherName: teacherName ?? this.teacherName,
      departmentId: departmentId ?? this.departmentId,
      departmentName: departmentName ?? this.departmentName,
      roomId: roomId ?? this.roomId,
      roomName: roomName ?? this.roomName,
      attendanceMode: attendanceMode ?? this.attendanceMode,
      customWindowStartMinutes:
          customWindowStartMinutes ?? this.customWindowStartMinutes,
      customWindowEndMinutes:
          customWindowEndMinutes ?? this.customWindowEndMinutes,
      enrolledCount: enrolledCount ?? this.enrolledCount,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      timeSlotId: timeSlotId ?? this.timeSlotId,
      timeSlotName: timeSlotName ?? this.timeSlotName,
      totalSessions: totalSessions ?? this.totalSessions,
      credits: credits ?? this.credits,
      isCourseActiveNow: isCourseActiveNow ?? this.isCourseActiveNow,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() =>
      'Course(id: $id, name: $courseName, code: $courseCode)';
}
