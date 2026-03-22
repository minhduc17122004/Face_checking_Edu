import 'package:face_time_keeping/common/api_client/data_state.dart';
import 'package:face_time_keeping/common/enums/request_status.dart';
import 'package:face_time_keeping/data/remote/course_service.dart';
import 'package:face_time_keeping/entities/course.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import 'course_state.dart';

@injectable
class CourseBloc extends Cubit<CourseState> {
  CourseBloc(this._courseService) : super(CourseState());

  final CourseService _courseService;

  Future<void> loadCourses({
    String? departmentId,
    bool mine = false,
  }) async {
    emit(state.copyWith(requestStatus: RequestStatus.requesting));
    final result = await _courseService.getCourses(
      departmentId: departmentId,
      mine: mine,
    );
    if (result.isSuccess) {
      emit(state.copyWith(
        requestStatus: RequestStatus.success,
        courses: result.data ?? [],
      ));
    } else {
      emit(state.copyWith(
        requestStatus: RequestStatus.failed,
        message: result.error ?? 'Failed to load courses',
      ));
    }
  }

  Future<void> loadCourseStudents(String courseId) async {
    emit(state.copyWith(requestStatus: RequestStatus.requesting));
    final result = await _courseService.getCourseStudents(courseId);
    if (result.isSuccess) {
      emit(state.copyWith(
        requestStatus: RequestStatus.success,
        students: result.data ?? [],
      ));
    } else {
      emit(state.copyWith(
        requestStatus: RequestStatus.failed,
        message: result.error ?? 'Failed to load students',
      ));
    }
  }

  Future<void> createCourse({
    required String courseName,
    String? subject,
    String? courseCode,
    String? departmentId,
    String? instructorId,
    String? roomId,
    AttendanceMode attendanceMode = AttendanceMode.preset,
    int attendanceBeforeMinutes = 30,
    int attendanceAfterMinutes = 30,
  }) async {
    emit(state.copyWith(requestStatus: RequestStatus.requesting));
    final result = await _courseService.createCourse(
      courseName: courseName,
      subject: subject,
      courseCode: courseCode,
      departmentId: departmentId,
      instructorId: instructorId,
      roomId: roomId,
      attendanceMode: attendanceMode,
      attendanceBeforeMinutes: attendanceBeforeMinutes,
      attendanceAfterMinutes: attendanceAfterMinutes,
    );
    if (result.isSuccess) {
      emit(state.copyWith(
        requestStatus: RequestStatus.success,
        selectedCourse: result.data,
      ));
      await loadCourses();
    } else {
      emit(state.copyWith(
        requestStatus: RequestStatus.failed,
        message: result.error ?? 'Failed to create course',
      ));
    }
  }

  Future<void> updateCourse({
    required String id,
    String? courseName,
    String? subject,
    String? courseCode,
    String? departmentId,
    String? roomId,
    AttendanceMode? attendanceMode,
    int? attendanceBeforeMinutes,
    int? attendanceAfterMinutes,
  }) async {
    emit(state.copyWith(requestStatus: RequestStatus.requesting));
    final result = await _courseService.updateCourse(
      id: id,
      courseName: courseName,
      subject: subject,
      courseCode: courseCode,
      departmentId: departmentId,
      roomId: roomId,
      attendanceMode: attendanceMode,
      attendanceBeforeMinutes: attendanceBeforeMinutes,
      attendanceAfterMinutes: attendanceAfterMinutes,
    );
    if (result.isSuccess) {
      emit(state.copyWith(
        requestStatus: RequestStatus.success,
        selectedCourse: result.data,
      ));
      await loadCourses();
    } else {
      emit(state.copyWith(
        requestStatus: RequestStatus.failed,
        message: result.error ?? 'Failed to update course',
      ));
    }
  }

  Future<void> assignRoom(String courseId, String roomId) async {
    emit(state.copyWith(requestStatus: RequestStatus.requesting));
    final result = await _courseService.assignRoom(courseId, roomId);
    if (result.isSuccess) {
      emit(state.copyWith(requestStatus: RequestStatus.success));
      await loadCourses();
    } else {
      emit(state.copyWith(
        requestStatus: RequestStatus.failed,
        message: result.error ?? 'Failed to assign room',
      ));
    }
  }

  Future<void> enrollStudent(String courseId, int studentId) async {
    emit(state.copyWith(requestStatus: RequestStatus.requesting));
    final result = await _courseService.enrollStudent(courseId, studentId);
    if (result.isSuccess) {
      emit(state.copyWith(requestStatus: RequestStatus.success));
      await loadCourseStudents(courseId);
    } else {
      emit(state.copyWith(
        requestStatus: RequestStatus.failed,
        message: result.error ?? 'Failed to enroll student',
      ));
    }
  }

  Future<void> unenrollStudent(String courseId, int studentId) async {
    emit(state.copyWith(requestStatus: RequestStatus.requesting));
    final result = await _courseService.unenrollStudent(courseId, studentId);
    if (result.isSuccess) {
      emit(state.copyWith(requestStatus: RequestStatus.success));
      await loadCourseStudents(courseId);
    } else {
      emit(state.copyWith(
        requestStatus: RequestStatus.failed,
        message: result.error ?? 'Failed to unenroll student',
      ));
    }
  }

  Future<void> deleteCourse(String id) async {
    emit(state.copyWith(requestStatus: RequestStatus.requesting));
    final result = await _courseService.deleteCourse(id);
    if (result.isSuccess) {
      emit(state.copyWith(requestStatus: RequestStatus.success));
      await loadCourses();
    } else {
      emit(state.copyWith(
        requestStatus: RequestStatus.failed,
        message: result.error ?? 'Failed to delete course',
      ));
    }
  }
}
