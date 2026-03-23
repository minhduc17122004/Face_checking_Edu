class StudentGroup {
  final String id;
  final String code;
  final String? name;
  final String? departmentId;
  final String? departmentName;
  final String? advisorId;
  final String? advisorName;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;

  const StudentGroup({
    required this.id,
    required this.code,
    this.name,
    this.departmentId,
    this.departmentName,
    this.advisorId,
    this.advisorName,
    required this.createdAt,
    this.updatedAt,
    this.deletedAt,
  });

  factory StudentGroup.fromJson(Map<String, dynamic> json) {
    return StudentGroup(
      id: json['id'] as String,
      code: json['code'] as String,
      name: json['name'] as String?,
      departmentId: json['department_id'] as String?,
      departmentName: json['department_name'] as String?,
      advisorId: json['advisor_id'] as String?,
      advisorName: json['advisor_name'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      deletedAt: json['deleted_at'] != null
          ? DateTime.parse(json['deleted_at'] as String)
          : null,
    );
  }
}