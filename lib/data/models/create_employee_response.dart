import 'package:face_time_keeping/entities/employee.dart';

/// Data object containing batch creation results
class BatchEmployeeResponse {
  final int totalReceived;
  final int successCount;
  final int failCount;
  final List<Employee> createdEmployees;
  final List<Employee>? failedDetails;

  BatchEmployeeResponse({
    required this.totalReceived,
    required this.successCount,
    required this.failCount,
    required this.createdEmployees,
    this.failedDetails,
  });

  factory BatchEmployeeResponse.fromJson(Map<String, dynamic> json) {
    return BatchEmployeeResponse(
      totalReceived: json['total_received'] ?? 0,
      successCount: json['success_count'] ?? 0,
      failCount: json['fail_count'] ?? 0,
      createdEmployees: json['created_employees'] != null
          ? (json['created_employees'] as List)
              .map((e) => Employee.fromJson(e))
              .toList()
          : [],
      failedDetails: json['failed_details'] != null
          ? (json['failed_details'] as List)
              .map((e) => Employee.fromErrorJson(e))
              .toList()
          : [],
    );
  }

  /// Check if all employees were created successfully
  bool get isFullySuccessful => failCount == 0;

  @override
  String toString() {
    return 'BatchCreationData(total: $totalReceived, success: $successCount, failed: $failCount)';
  }
}
