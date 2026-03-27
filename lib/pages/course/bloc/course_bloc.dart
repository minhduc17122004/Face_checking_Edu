import 'package:face_time_keeping/common/api_client/data_state.dart';
import 'package:face_time_keeping/common/enums/request_status.dart';
import 'package:face_time_keeping/common/event/event_bus_event.dart';
import 'package:face_time_keeping/common/event/event_bus_mixin.dart';
import 'package:face_time_keeping/data/remote/course_service.dart';
import 'package:face_time_keeping/entities/course.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import 'course_state.dart';

@lazySingleton
class CourseBloc extends Cubit<CourseState> with EventBusMixin {
  CourseBloc(this._courseService) : super(CourseState()) {
    listenEvent<CourseChangeEvent>((event) {
      loadCourses(
        departmentId: _lastDepartmentId,
        mine: _lastMine,
      );
    });
  }

  final CourseService _courseService;
  String? _lastDepartmentId;
  bool _lastMine = false;

  Future<void> loadCourses({
    String? departmentId,
    bool mine = false,
  }) async {
    _lastDepartmentId = departmentId;
    _lastMine = mine;
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

  Future<void> loadCourseDetail(String courseId) async {
    final result = await _courseService.getCourse(courseId);
    if (result.isSuccess) {
      emit(state.copyWith(
        selectedCourse: result.data,
      ));
    }
  }

  Future<void> createCourse({
    required String courseName,
    String? courseCode,
    String? departmentId,
    int? teacherId,
    String? roomId,
    AttendanceMode attendanceMode = AttendanceMode.preset,
    int customWindowStartMinutes = 0,
    int customWindowEndMinutes = 30,
    int? dayOfWeek,
    int? timeSlotId,
  }) async {
    emit(state.copyWith(requestStatus: RequestStatus.requesting));
    final result = await _courseService.createCourse(
      courseName: courseName,
      courseCode: courseCode,
      departmentId: departmentId,
      teacherId: teacherId,
      roomId: roomId,
      attendanceMode: attendanceMode,
      customWindowStartMinutes: customWindowStartMinutes,
      customWindowEndMinutes: customWindowEndMinutes,
      dayOfWeek: dayOfWeek,
      timeSlotId: timeSlotId,
    );
    if (result.isSuccess) {
      emit(state.copyWith(
        requestStatus: RequestStatus.success,
        selectedCourse: result.data,
        message: 'Success',
      ));
      await loadCourses();
      shareEvent(CourseChangeEvent());
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
    String? courseCode,
    String? departmentId,
    int? teacherId,
    String? roomId,
    AttendanceMode? attendanceMode,
    int? customWindowStartMinutes,
    int? customWindowEndMinutes,
    int? dayOfWeek,
    int? timeSlotId,
  }) async {
    emit(state.copyWith(requestStatus: RequestStatus.requesting));
    final result = await _courseService.updateCourse(
      id: id,
      courseName: courseName,
      courseCode: courseCode,
      departmentId: departmentId,
      teacherId: teacherId,
      roomId: roomId,
      attendanceMode: attendanceMode,
      customWindowStartMinutes: customWindowStartMinutes,
      customWindowEndMinutes: customWindowEndMinutes,
      dayOfWeek: dayOfWeek,
      timeSlotId: timeSlotId,
    );
    if (result.isSuccess) {
      emit(state.copyWith(
        requestStatus: RequestStatus.success,
        selectedCourse: result.data,
        message: 'Success',
      ));
      await loadCourses();
      shareEvent(CourseChangeEvent());
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

  Future<Map<String, dynamic>?> batchEnrollStudents(
      String courseId, List<int> studentIds) async {
    emit(state.copyWith(requestStatus: RequestStatus.requesting));
    final result =
        await _courseService.batchEnrollStudents(courseId, studentIds);
    if (result.isSuccess) {
      emit(state.copyWith(requestStatus: RequestStatus.success));
      await loadCourseStudents(courseId);
      return result.data;
    } else {
      emit(state.copyWith(
        requestStatus: RequestStatus.failed,
        message: result.error ?? 'Failed to enroll students',
      ));
      return null;
    }
  }

  Future<List<Map<String, dynamic>>?> getAvailableStudents(String courseId) async {
    final result = await _courseService.getAvailableStudents(courseId);
    if (result.isSuccess) {
      return result.data;
    }
    return null;
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
      shareEvent(CourseChangeEvent());
    } else {
      emit(state.copyWith(
        requestStatus: RequestStatus.failed,
        message: result.error ?? 'Failed to delete course',
      ));
    }
  }

  void clearDetail() {
    emit(CourseState(
      requestStatus: RequestStatus.initial,
      courses: state.courses,
      students: const [],
      message: null,
      selectedCourse: null,
    ));
  }
}
