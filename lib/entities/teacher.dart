class Teacher {
  final int id;
  final String userId;
  final String? teacherId;
  final String? phone;
  final String? departmentId;
  final String? departmentName;
  final String? userFullName;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const Teacher({
    required this.id,
    required this.userId,
    this.teacherId,
    this.phone,
    this.departmentId,
    this.departmentName,
    this.userFullName,
    required this.createdAt,
    this.updatedAt,
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
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'teacher_id': teacherId,
      'phone': phone,
      'department_id': departmentId,
      'department_name': departmentName,
      'user_full_name': userFullName,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  @override
  String toString() => 'Teacher(id: $id, name: $userFullName)';
}
