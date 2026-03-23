class CourseStudent {
  final int studentId;
  final String? userId;
  final String? pin;
  final String? name;
  final bool hasFace;
  final int embeddingCount;
  final DateTime enrolledAt;

  const CourseStudent({
    required this.studentId,
    this.userId,
    this.pin,
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
      name: json['name'] as String?,
      hasFace: json['has_face'] as bool? ?? false,
      embeddingCount: json['embedding_count'] as int? ?? 0,
      enrolledAt: DateTime.parse(json['enrolled_at'] as String),
    );
  }

  @override
  String toString() =>
      'CourseStudent(studentId: $studentId, pin: $pin, hasFace: $hasFace)';
}

class Teacher {
  final int id;
  final String userId;
  final String? teacherId;
  final String? phone;
  final String? departmentId;
  final String? departmentName;
  final String? userFullName;
  final DateTime createdAt;

  const Teacher({
    required this.id,
    required this.userId,
    this.teacherId,
    this.phone,
    this.departmentId,
    this.departmentName,
    this.userFullName,
    required this.createdAt,
  });

  factory Teacher.fromJson(Map<String, dynamic> json) {
    return Teacher(
      id: json['id'] as int,
      userId: json['user_id'] as String,
      teacherId: json['teacher_id'] as String?,
      phone: json['phone'] as String?,
      departmentId: json['department_id'] as String?,
      departmentName: json['department_name'] as String?,
      userFullName: json['user_full_name'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  @override
  String toString() =>
      'Teacher(id: $id, userId: $userId, departmentId: $departmentId)';
}
