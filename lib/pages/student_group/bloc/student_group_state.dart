import 'package:face_time_keeping/common/enums/request_status.dart';
import 'package:face_time_keeping/entities/student_group.dart';
import 'package:face_time_keeping/entities/department.dart';
import 'package:face_time_keeping/entities/course_student.dart';
import 'package:face_time_keeping/entities/teacher.dart';

class StudentGroupState {
  final RequestStatus requestStatus;
  final List<StudentGroup> studentGroups;
  final List<Department> departments;
  final List<Teacher> teachers;
  final String? message;
  final StudentGroup? selectedStudentGroup;

  StudentGroupState({
    this.requestStatus = RequestStatus.initial,
    this.studentGroups = const [],
    this.departments = const [],
    this.teachers = const [],
    this.message,
    this.selectedStudentGroup,
  });

  StudentGroupState copyWith({
    RequestStatus? requestStatus,
    List<StudentGroup>? studentGroups,
    List<Department>? departments,
    List<Teacher>? teachers,
    String? message,
    StudentGroup? selectedStudentGroup,
  }) {
    return StudentGroupState(
      requestStatus: requestStatus ?? this.requestStatus,
      studentGroups: studentGroups ?? this.studentGroups,
      departments: departments ?? this.departments,
      teachers: teachers ?? this.teachers,
      message: message,
      selectedStudentGroup: selectedStudentGroup ?? this.selectedStudentGroup,
    );
  }
}
