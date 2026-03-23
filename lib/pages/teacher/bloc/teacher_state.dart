import 'package:face_time_keeping/common/enums/request_status.dart';
import 'package:face_time_keeping/entities/course_student.dart';
import 'package:face_time_keeping/entities/teacher.dart';

class TeacherState {
  final RequestStatus requestStatus;
  final List<Teacher> teachers;
  final String? message;

  TeacherState({
    this.requestStatus = RequestStatus.initial,
    this.teachers = const [],
    this.message,
  });

  TeacherState copyWith({
    RequestStatus? requestStatus,
    List<Teacher>? teachers,
    String? message,
  }) {
    return TeacherState(
      requestStatus: requestStatus ?? this.requestStatus,
      teachers: teachers ?? this.teachers,
      message: message,
    );
  }
}
