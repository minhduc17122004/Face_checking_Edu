class CourseStudent {
  final int studentId;
  final String? userId;
  final String? pin;
  final String? studentCode;
  final String? name;
  final bool hasFace;
  final int embeddingCount;
  final DateTime enrolledAt;

  const CourseStudent({
    required this.studentId,
    this.userId,
    this.pin,
    this.studentCode,
    this.name,
    this.hasFace = false,
    this.embeddingCount = 0,
    required this.enrolledAt,
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
    );
  }

  @override
  String toString() =>
      'CourseStudent(studentId: $studentId, studentCode: $studentCode, hasFace: $hasFace)';
}
