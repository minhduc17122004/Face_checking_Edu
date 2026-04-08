class CourseStudent {
  final int studentId;
  final String? userId;
  final String? pin;
  final String? studentCode;
  final String? name;
  final bool hasFace;
  final int embeddingCount;
  final DateTime enrolledAt;
  final int absentCount;
  final int leaveCount;
  final int lateCount;
  final int onTimeCount;

  const CourseStudent({
    required this.studentId,
    this.userId,
    this.pin,
    this.studentCode,
    this.name,
    this.hasFace = false,
    this.embeddingCount = 0,
    required this.enrolledAt,
    this.absentCount = 0,
    this.leaveCount = 0,
    this.lateCount = 0,
    this.onTimeCount = 0,
  });

  factory CourseStudent.fromJson(Map<String, dynamic> json) {
    return CourseStudent(
      studentId: json['student_id'] as int,
      userId: json['user_id'] as String?,
      pin: json['pin'] as String?,
      studentCode: json['student_code'] as String?,
      name: json['name'] as String?,
      hasFace: json['has_face'] as bool? ?? false,
      embeddingCount: json['embedding_count'] as int? ?? 0,
      enrolledAt: DateTime.parse(json['enrolled_at'] as String),
      absentCount: json['absent_count'] as int? ?? 0,
      leaveCount: json['leave_count'] as int? ?? 0,
      lateCount: json['late_count'] as int? ?? 0,
      onTimeCount: json['on_time_count'] as int? ?? 0,
    );
  }

  @override
  String toString() =>
      'CourseStudent(studentId: $studentId, studentCode: $studentCode, hasFace: $hasFace)';
}
