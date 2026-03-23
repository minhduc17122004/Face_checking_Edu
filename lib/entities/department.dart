class Department {
  final String id;
  final String code;
  final String name;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final int teacherCount;
  final int studentCount;

  const Department({
    required this.id,
    required this.code,
    required this.name,
    required this.createdAt,
    this.updatedAt,
    this.teacherCount = 0,
    this.studentCount = 0,
  });

  factory Department.fromJson(Map<String, dynamic> json) {
    return Department(
      id: json['id'] as String,
      code: json['code'] as String,
      name: json['name'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      teacherCount: json['teacher_count'] as int? ?? 0,
      studentCount: json['student_count'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'name': name,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'teacher_count': teacherCount,
      'student_count': studentCount,
    };
  }

  Department copyWith({
    String? id,
    String? code,
    String? name,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? teacherCount,
    int? studentCount,
  }) {
    return Department(
      id: id ?? this.id,
      code: code ?? this.code,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      teacherCount: teacherCount ?? this.teacherCount,
      studentCount: studentCount ?? this.studentCount,
    );
  }

  @override
  String toString() => 'Department(id: $id, code: $code, name: $name)';
}
