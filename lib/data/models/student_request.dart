import 'package:face_time_keeping/common/utils/extensions/interable_extension.dart';

/// Represents an individual student in the batch creation request
class StudentRequest {
  final String name;
  final String pin;
  final String jobTitle;
  final String? avatar;

  StudentRequest({
    required this.name,
    required this.pin,
    required this.jobTitle,
    this.avatar,
  });

  factory StudentRequest.fromJson(Map<String, dynamic> json) {
    return StudentRequest(
      name: json['name'] as String,
      pin: json['pin'] as String,
      jobTitle: json['job_title'] as String,
      avatar: json['avatar_ref'] as String?,
    );
  }

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
    return 'Student(name: $name, pin: $pin, jobTitle: $jobTitle)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is StudentRequest &&
        other.name == name &&
        other.pin == pin &&
        other.jobTitle == jobTitle;
  }

  @override
  int get hashCode => name.hashCode ^ pin.hashCode ^ jobTitle.hashCode;
}

/// Represents the batch student creation request payload
class CreateStudentBatchRequest {
  final String? uploadId;
  final List<StudentRequest> students;

  CreateStudentBatchRequest({
    this.uploadId,
    required this.students,
  });

  factory CreateStudentBatchRequest.fromJson(Map<String, dynamic> json) {
    return CreateStudentBatchRequest(
      students: (json['students'] as List<dynamic>)
          .map((e) => StudentRequest.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'upload_id': uploadId,
      'students': students.map((e) => e.toJson()).toList(),
    }.removeNullAndEmpty();
  }

  @override
  String toString() {
    return 'CreateStudentBatchRequest(students: $students)';
  }
}
