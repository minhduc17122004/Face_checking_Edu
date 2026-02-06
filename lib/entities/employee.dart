import 'package:face_time_keeping/entities/person.dart';

class Employee {
  final int id;
  final String? pin;

  final String name;
  final dynamic jobTitle; // Can be false or string
  final bool hasAvatar;
  final dynamic error;
  final String? attachmentId;
  final String? avatar;

  Employee({
    required this.id,
    required this.pin,
    required this.name,
    this.jobTitle,
    this.hasAvatar = false,
    this.error,
    this.attachmentId,
    this.avatar,
  });

  factory Employee.fromJson(Map<String, dynamic> json) {
    return Employee(
        id: json['id'] as int,
        pin: json['pin'] is String ? json['pin'] as String : null,
        name: json['name'] as String,
        jobTitle: json['job_title'],
        hasAvatar: json['has_avatar'] as bool? ?? false,
        error: json['error'],
        attachmentId: json['attachment_id'] is String
            ? json['attachment_id'] as String
            : null,
        avatar:
            json['avatar_url'] is String ? json['avatar_url'] as String : null);
  }

  factory Employee.fromErrorJson(Map<String, dynamic> json) {
    return Employee(
      id: -1,
      pin: json['pin'] is String ? json['pin'] as String : null,
      name: json['name'] as String,
      jobTitle: json['job_title'],
      hasAvatar: json['has_avatar'] as bool? ?? false,
      error: json['error'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'pin': pin,
      'name': name,
      'job_title': jobTitle,
      'has_avatar': hasAvatar,
      'error': error,
      'attachment_id': attachmentId,
      'avatar_url': avatar,
    };
  }

  @override
  String toString() {
    return 'Employee(id: $id, pin: $pin, name: $name, jobTitle: $jobTitle)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Employee &&
        other.id == id &&
        other.pin == pin &&
        other.name == name &&
        other.jobTitle == jobTitle;
  }

  @override
  int get hashCode {
    return id.hashCode ^ pin.hashCode ^ name.hashCode ^ jobTitle.hashCode;
  }

  Employee copyWith({
    int? id,
    String? pin,
    dynamic barcode,
    String? name,
    dynamic jobTitle,
  }) {
    return Employee(
      id: id ?? this.id,
      pin: pin ?? this.pin,
      name: name ?? this.name,
      jobTitle: jobTitle ?? this.jobTitle,
    );
  }

  Person toPerson() {
    return Person(
      employeeId: id,
      pin: pin,
      name: name,
      jobTitle: jobTitle,
      updatedTime: DateTime.now(),
    );
  }
}
