import 'package:face_time_keeping/entities/student.dart' as student_entity;
import 'package:face_time_keeping/pages/widgets/content_widget.dart';

class StudentState {
  final List<student_entity.Student>? students;
  final List<student_entity.Student>? studentsFromServer;
  final List<student_entity.Student>? mergedStudents;
  final DataSourceStatus status;
  final DataSourceStatus serverStatus;
  final String? error;
  final String? syncMessage;

  const StudentState({
    this.students,
    this.studentsFromServer,
    this.mergedStudents,
    this.status = DataSourceStatus.initial,
    this.serverStatus = DataSourceStatus.initial,
    this.error,
    this.syncMessage,
  });

  StudentState copyWith({
    List<student_entity.Student>? students,
    List<student_entity.Student>? studentsFromServer,
    List<student_entity.Student>? mergedStudents,
    DataSourceStatus? status,
    DataSourceStatus? serverStatus,
    String? error,
    String? syncMessage,
  }) {
    return StudentState(
      students: students ?? this.students,
      studentsFromServer: studentsFromServer ?? this.studentsFromServer,
      mergedStudents: mergedStudents ?? this.mergedStudents,
      status: status ?? this.status,
      serverStatus: serverStatus ?? this.serverStatus,
      error: error,
      syncMessage: syncMessage,
    );
  }
}
