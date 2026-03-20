import 'package:face_time_keeping/entities/student.dart';

/// Data object containing batch creation results
class BatchStudentResponse {
  final int totalReceived;
  final int successCount;
  final int failCount;
  final List<Student> createdStudents;
  final List<Student>? failedDetails;

  BatchStudentResponse({
    required this.totalReceived,
    required this.successCount,
    required this.failCount,
    required this.createdStudents,
    this.failedDetails,
  });

  factory BatchStudentResponse.fromJson(Map<String, dynamic> json) {
    return BatchStudentResponse(
      totalReceived: json['total_received'] ?? 0,
      successCount: json['success_count'] ?? 0,
      failCount: json['fail_count'] ?? 0,
      createdStudents: json['created_students'] != null
          ? (json['created_students'] as List)
              .map((e) => Student.fromJson(e))
              .toList()
          : [],
      failedDetails: json['failed_details'] != null
          ? (json['failed_details'] as List)
              .map((e) => Student.fromErrorJson(e))
              .toList()
          : [],
    );
  }

  bool get isFullySuccessful => failCount == 0;

  @override
  String toString() {
    return 'BatchCreationData(total: $totalReceived, success: $successCount, failed: $failCount)';
  }
}
