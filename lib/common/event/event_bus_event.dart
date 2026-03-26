import 'package:face_time_keeping/data/models/logging_model.dart';

bool showLogout = false;

class LogoutEvent {
  String? message;

  LogoutEvent({
    this.message,
  });
}

class NetworkStatusChangeEvent {
  NetworkStatusChangeEvent({this.status = true});
  final bool status;
}

class LoggingEvent {
  LoggingEvent({required this.apiInfo});
  final ApiInfo apiInfo;
}

class SyncDataEvent {}

class AttendanceChangeEvent {}

class CourseChangeEvent {}

class SyncStudentEvent {
  SyncStudentEvent({
    required this.status,
    this.success,
    this.message,
  });

  final String status; // 'in_progress', 'success', 'failed'
  final bool? success;
  final String? message;
}

class DidChangeStudentEvent {
  Student? student;
  DidChangeStudentEvent(this.student);
}

class AvatarChangedEvent {
  AvatarChangedEvent({required this.avatarPath});

  final String avatarPath;
}

class Student {
  final int? id;
  final String? name;

  Student({this.id, this.name});
}
