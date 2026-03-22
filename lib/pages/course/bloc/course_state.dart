import 'package:face_time_keeping/common/enums/request_status.dart';
import 'package:face_time_keeping/entities/course.dart';
import 'package:face_time_keeping/entities/course_student.dart';

class CourseState {
  final RequestStatus requestStatus;
  final List<Course> courses;
  final List<CourseStudent> students;
  final String? message;
  final Course? selectedCourse;

  CourseState({
    this.requestStatus = RequestStatus.initial,
    this.courses = const [],
    this.students = const [],
    this.message,
    this.selectedCourse,
  });

  CourseState copyWith({
    RequestStatus? requestStatus,
    List<Course>? courses,
    List<CourseStudent>? students,
    String? message,
    Course? selectedCourse,
  }) {
    return CourseState(
      requestStatus: requestStatus ?? this.requestStatus,
      courses: courses ?? this.courses,
      students: students ?? this.students,
      message: message,
      selectedCourse: selectedCourse ?? this.selectedCourse,
    );
  }
}
