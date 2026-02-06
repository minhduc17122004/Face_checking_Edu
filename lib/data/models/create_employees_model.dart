import 'package:face_time_keeping/common/utils/extensions/interable_extension.dart';

/// Represents an individual employee in the batch creation request
class EmployeeRequest {
  final String name;
  final String pin;
  final String jobTitle;
  final String? avatar;

  EmployeeRequest({
    required this.name,
    required this.pin,
    required this.jobTitle,
    this.avatar,
  });

  /// Creates an Employee instance from a JSON map
  factory EmployeeRequest.fromJson(Map<String, dynamic> json) {
    return EmployeeRequest(
      name: json['name'] as String,
      pin: json['pin'] as String,
      jobTitle: json['job_title'] as String,
      avatar: json['avatar_ref'] as String?,
    );
  }

  /// Converts the Employee instance to a JSON map
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'pin': pin,
      'job_title': jobTitle,
      'avatar_ref': avatar,
    }.removeNullAndEmpty();
  }

  @override
  String toString() {
    return 'Employee(name: $name, pin: $pin, jobTitle: $jobTitle)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is EmployeeRequest &&
        other.name == name &&
        other.pin == pin &&
        other.jobTitle == jobTitle;
  }

  @override
  int get hashCode => name.hashCode ^ pin.hashCode ^ jobTitle.hashCode;
}

/// Represents the batch employee creation request payload
class CreateEmployeeBatchRequest {
  final String? uploadId;
  final List<EmployeeRequest> employees;

  CreateEmployeeBatchRequest({
    this.uploadId,
    required this.employees,
  });

  /// Creates a CreateEmployeeBatchRequest instance from a JSON map
  factory CreateEmployeeBatchRequest.fromJson(Map<String, dynamic> json) {
    return CreateEmployeeBatchRequest(
      employees: (json['employees'] as List<dynamic>)
          .map((e) => EmployeeRequest.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Converts the CreateEmployeeBatchRequest instance to a JSON map
  Map<String, dynamic> toJson() {
    return {
      'upload_id': uploadId,
      'employees': employees.map((e) => e.toJson()).toList(),
    }.removeNullAndEmpty();
  }

  @override
  String toString() {
    return 'CreateEmployeeBatchRequest(employees: $employees)';
  }
}
