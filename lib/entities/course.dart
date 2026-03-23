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
        return '30 phút trước - 30 phút sau giờ học';
      case AttendanceMode.flexible:
        return 'Luôn cho phép điểm danh';
      case AttendanceMode.custom:
        return 'Tự thiết lập thời gian';
    }
  }

  String get shortLabel {
    switch (this) {
      case AttendanceMode.preset:
        return 'Đặt trước';
      case AttendanceMode.flexible:
        return 'Linh hoạt';
      case AttendanceMode.custom:
        return 'Tùy chỉnh';
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
  final int attendanceBeforeMinutes;
  final int attendanceAfterMinutes;
  final int enrolledCount;
  final int? dayOfWeek;
  final int? timeSlotId;
  final String? timeSlotName;
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
    this.attendanceBeforeMinutes = 30,
    this.attendanceAfterMinutes = 30,
    this.enrolledCount = 0,
    this.dayOfWeek,
    this.timeSlotId,
    this.timeSlotName,
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
      attendanceBeforeMinutes:
          json['attendance_before_minutes'] as int? ?? 30,
      attendanceAfterMinutes:
          json['attendance_after_minutes'] as int? ?? 30,
      enrolledCount: json['enrolled_count'] as int? ?? 0,
      dayOfWeek: json['day_of_week'] as int?,
      timeSlotId: json['time_slot_id'] as int?,
      timeSlotName: json['time_slot_name'] as String?,
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
      'attendance_before_minutes': attendanceBeforeMinutes,
      'attendance_after_minutes': attendanceAfterMinutes,
      'day_of_week': dayOfWeek,
      'time_slot_id': timeSlotId,
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
    int? attendanceBeforeMinutes,
    int? attendanceAfterMinutes,
    int? enrolledCount,
    int? dayOfWeek,
    int? timeSlotId,
    String? timeSlotName,
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
      attendanceBeforeMinutes:
          attendanceBeforeMinutes ?? this.attendanceBeforeMinutes,
      attendanceAfterMinutes:
          attendanceAfterMinutes ?? this.attendanceAfterMinutes,
      enrolledCount: enrolledCount ?? this.enrolledCount,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      timeSlotId: timeSlotId ?? this.timeSlotId,
      timeSlotName: timeSlotName ?? this.timeSlotName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() =>
      'Course(id: $id, name: $courseName, code: $courseCode)';
}
