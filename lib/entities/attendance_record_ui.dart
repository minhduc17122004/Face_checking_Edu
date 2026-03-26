class AttendanceRecordUI {
  final String id;
  final int studentId;
  final String? studentName;
  final String? studentCode;
  final DateTime checkinTime;
  final String status;
  final int? minutesDiff;
  final String? deviceId;

  const AttendanceRecordUI({
    required this.id,
    required this.studentId,
    this.studentName,
    this.studentCode,
    required this.checkinTime,
    this.status = 'present',
    this.minutesDiff,
    this.deviceId,
  });

  factory AttendanceRecordUI.fromJson(Map<String, dynamic> json) {
    return AttendanceRecordUI(
      id: json['id'] as String,
      studentId: json['student_id'] as int,
      studentName: json['student_name'] as String?,
      studentCode: json['student_code'] as String?,
      checkinTime: DateTime.parse(json['checkin_time'] as String),
      status: json['status'] as String? ?? 'present',
      minutesDiff: json['minutes_diff'] as int?,
      deviceId: json['device_id'] as String?,
    );
  }

  bool get isPresent => status == 'present';
  bool get isLate => status == 'late';
  bool get isAbsent => status == 'absent';
  bool get isOnTime => status == 'on_time';
  bool get isEarly => status == 'early';

  bool get isCheckedIn => isPresent || isLate || isOnTime || isEarly;

  String get formattedCheckinTime {
    return '${checkinTime.hour.toString().padLeft(2, '0')}:${checkinTime.minute.toString().padLeft(2, '0')}';
  }

  String get minutesDiffLabel {
    if (minutesDiff == null) return '';
    if (minutesDiff! > 0) return '+${minutesDiff}m';
    return '${minutesDiff}m';
  }

  String get displayName => studentName ?? 'HS_$studentId';

  @override
  String toString() =>
      'AttendanceRecordUI(id: $id, student: $displayName, status: $status)';
}
