import 'package:dio/dio.dart';
import 'package:face_time_keeping/common/utils/log_util.dart';
import 'package:injectable/injectable.dart';

import '../../common/api_client/api_client.dart';
import '../../common/api_client/api_response.dart';
import '../../common/api_client/data_state.dart';
import '../../entities/course.dart';
import '../../entities/course_student.dart';
import '../../entities/room.dart';
import 'api_endpoint.dart';

abstract class CourseService {
  Future<DataState<List<Course>>> getCourses({
    String? departmentId,
    bool mine = false,
    int? limit,
    int? offset,
  });
  Future<DataState<Course>> getCourse(String id);
  Future<DataState<Course>> createCourse({
    required String courseName,
    String? courseCode,
    String? departmentId,
    int? teacherId,
    String? roomId,
    AttendanceMode attendanceMode = AttendanceMode.preset,
    int attendanceBeforeMinutes = 30,
    int attendanceAfterMinutes = 30,
    int? dayOfWeek,
    int? timeSlotId,
  });
  Future<DataState<Course>> updateCourse({
    required String id,
    String? courseName,
    String? courseCode,
    String? departmentId,
    int? teacherId,
    String? roomId,
    AttendanceMode? attendanceMode,
    int? attendanceBeforeMinutes,
    int? attendanceAfterMinutes,
    int? dayOfWeek,
    int? timeSlotId,
  });
  Future<DataState<void>> deleteCourse(String id);
  Future<DataState<Room?>> assignRoom(String courseId, String roomId);
  Future<DataState<List<CourseStudent>>> getCourseStudents(String courseId);
  Future<DataState<void>> enrollStudent(String courseId, int studentId);
  Future<DataState<Map<String, dynamic>>> batchEnrollStudents(String courseId, List<int> studentIds);
  Future<DataState<List<Map<String, dynamic>>>> getAvailableStudents(String courseId, {int? limit, int? offset});
  Future<DataState<void>> unenrollStudent(String courseId, int studentId);
}

@LazySingleton(as: CourseService)
class CourseServiceImplement implements CourseService {
  CourseServiceImplement(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<DataState<List<Course>>> getCourses({
    String? departmentId,
    bool mine = false,
    int? limit,
    int? offset,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (departmentId != null) queryParams['department_id'] = departmentId;
      if (mine) queryParams['mine'] = 'true';
      if (limit != null) queryParams['limit'] = limit;
      if (offset != null) queryParams['skip'] = offset;

      final ApiResponse response = await _apiClient.get(
        path: ApiEndpoint.courses,
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );
      if (response.isSuccess()) {
        final json = response.data as Map<String, dynamic>;
        final items = json['items'] as List<dynamic>;
        final courses = items
            .map((e) => Course.fromJson(e as Map<String, dynamic>))
            .toList();
        return DataSuccess<List<Course>>(courses);
      }
      return DataFailed<List<Course>>(response.error);
    } on DioError catch (e) {
      await pushLog('Error in getCourses: $e');
      return DataFailed<List<Course>>(e.message);
    } on Exception catch (e) {
      await pushLog('Error in getCourses: $e');
      return DataFailed<List<Course>>(e.toString());
    }
  }

  @override
  Future<DataState<Course>> getCourse(String id) async {
    try {
      final response = await _apiClient.get(path: '${ApiEndpoint.courses}/$id');
      if (response.isSuccess()) {
        return DataSuccess<Course>(
          Course.fromJson(response.data as Map<String, dynamic>),
        );
      }
      return DataFailed<Course>(response.error);
    } on DioError catch (e) {
      await pushLog('Error in getCourse: $e');
      return DataFailed<Course>(e.message);
    } on Exception catch (e) {
      await pushLog('Error in getCourse: $e');
      return DataFailed<Course>(e.toString());
    }
  }

  @override
  Future<DataState<Course>> createCourse({
    required String courseName,
    String? courseCode,
    String? departmentId,
    int? teacherId,
    String? roomId,
    AttendanceMode attendanceMode = AttendanceMode.preset,
    int attendanceBeforeMinutes = 30,
    int attendanceAfterMinutes = 30,
    int? dayOfWeek,
    int? timeSlotId,
  }) async {
    try {
      final response = await _apiClient.post(
        path: ApiEndpoint.courses,
        data: {
          'course_name': courseName,
          if (courseCode != null) 'course_code': courseCode,
          if (departmentId != null) 'department_id': departmentId,
          if (teacherId != null) 'teacher_id': teacherId,
          if (roomId != null) 'room_id': roomId,
          'attendance_mode': attendanceMode.value,
          'attendance_before_minutes': attendanceBeforeMinutes,
          'attendance_after_minutes': attendanceAfterMinutes,
          if (dayOfWeek != null) 'day_of_week': dayOfWeek,
          if (timeSlotId != null) 'time_slot_id': timeSlotId,
        },
        sendTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 20),
      );
      if (response.isSuccess()) {
        return DataSuccess<Course>(
          Course.fromJson(response.data as Map<String, dynamic>),
        );
      }
      return DataFailed<Course>(response.error);
    } on DioError catch (e) {
      await pushLog('Error in createCourse: $e');
      return DataFailed<Course>(e.message);
    } on Exception catch (e) {
      await pushLog('Error in createCourse: $e');
      return DataFailed<Course>(e.toString());
    }
  }

  @override
  Future<DataState<Course>> updateCourse({
    required String id,
    String? courseName,
    String? courseCode,
    String? departmentId,
    int? teacherId,
    String? roomId,
    AttendanceMode? attendanceMode,
    int? attendanceBeforeMinutes,
    int? attendanceAfterMinutes,
    int? dayOfWeek,
    int? timeSlotId,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (courseName != null) data['course_name'] = courseName;
      if (courseCode != null) data['course_code'] = courseCode;
      if (departmentId != null) data['department_id'] = departmentId;
      if (roomId != null) data['room_id'] = roomId;
      if (teacherId != null) data['teacher_id'] = teacherId;
      if (attendanceMode != null)
        data['attendance_mode'] = attendanceMode.value;
      if (attendanceBeforeMinutes != null) {
        data['attendance_before_minutes'] = attendanceBeforeMinutes;
      }
      if (attendanceAfterMinutes != null) {
        data['attendance_after_minutes'] = attendanceAfterMinutes;
      }
      if (dayOfWeek != null) data['day_of_week'] = dayOfWeek;
      if (timeSlotId != null) data['time_slot_id'] = timeSlotId;

      final response = await _apiClient.put(
        path: '${ApiEndpoint.courses}/$id',
        data: data,
        sendTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 20),
      );
      if (response.isSuccess()) {
        return DataSuccess<Course>(
          Course.fromJson(response.data as Map<String, dynamic>),
        );
      }
      return DataFailed<Course>(response.error);
    } on DioError catch (e) {
      await pushLog('Error in updateCourse: $e');
      return DataFailed<Course>(e.message);
    } on Exception catch (e) {
      await pushLog('Error in updateCourse: $e');
      return DataFailed<Course>(e.toString());
    }
  }

  @override
  Future<DataState<void>> deleteCourse(String id) async {
    try {
      final response =
          await _apiClient.delete(path: '${ApiEndpoint.courses}/$id');
      if (response.isSuccess()) {
        return const DataSuccess<void>(null);
      }
      return DataFailed<void>(response.error);
    } on DioError catch (e) {
      await pushLog('Error in deleteCourse: $e');
      return DataFailed<void>(e.message);
    } on Exception catch (e) {
      await pushLog('Error in deleteCourse: $e');
      return DataFailed<void>(e.toString());
    }
  }

  @override
  Future<DataState<Room?>> assignRoom(String courseId, String roomId) async {
    try {
      final response = await _apiClient.put(
        path: ApiEndpoint.courseAssignRoom.replaceFirst('{id}', courseId),
        data: {'room_id': roomId},
      );
      if (response.isSuccess()) {
        return DataSuccess<Room?>(
          Room.fromJson(response.data as Map<String, dynamic>),
        );
      }
      return DataFailed<Room?>(response.error);
    } on DioError catch (e) {
      await pushLog('Error in assignRoom: $e');
      return DataFailed<Room?>(e.message);
    } on Exception catch (e) {
      await pushLog('Error in assignRoom: $e');
      return DataFailed<Room?>(e.toString());
    }
  }

  @override
  Future<DataState<List<CourseStudent>>> getCourseStudents(
      String courseId) async {
    try {
      final response = await _apiClient.get(
        path: ApiEndpoint.courseStudents.replaceFirst('{id}', courseId),
      );
      if (response.isSuccess()) {
        final json = response.data as Map<String, dynamic>;
        final students = json['students'] as List<dynamic>;
        final courseStudents = students
            .map((e) => CourseStudent.fromJson(e as Map<String, dynamic>))
            .toList();
        return DataSuccess<List<CourseStudent>>(courseStudents);
      }
      return DataFailed<List<CourseStudent>>(response.error);
    } on DioError catch (e) {
      await pushLog('Error in getCourseStudents: $e');
      return DataFailed<List<CourseStudent>>(e.message);
    } on Exception catch (e) {
      await pushLog('Error in getCourseStudents: $e');
      return DataFailed<List<CourseStudent>>(e.toString());
    }
  }

  @override
  Future<DataState<void>> enrollStudent(String courseId, int studentId) async {
    try {
      final response = await _apiClient.post(
        path: '${ApiEndpoint.courses}/$courseId/students/$studentId',
      );
      if (response.isSuccess()) {
        return const DataSuccess<void>(null);
      }
      return DataFailed<void>(response.error);
    } on DioError catch (e) {
      await pushLog('Error in enrollStudent: $e');
      return DataFailed<void>(e.message);
    } on Exception catch (e) {
      await pushLog('Error in enrollStudent: $e');
      return DataFailed<void>(e.toString());
    }
  }

  @override
  Future<DataState<Map<String, dynamic>>> batchEnrollStudents(
      String courseId, List<int> studentIds) async {
    try {
      final response = await _apiClient.post(
        path: '${ApiEndpoint.courses}/$courseId/students/batch',
        data: {'student_ids': studentIds},
        sendTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
      );
      if (response.isSuccess()) {
        return DataSuccess<Map<String, dynamic>>(
          response.data as Map<String, dynamic>,
        );
      }
      return DataFailed<Map<String, dynamic>>(response.error);
    } on DioError catch (e) {
      await pushLog('Error in batchEnrollStudents: $e');
      return DataFailed<Map<String, dynamic>>(e.message);
    } on Exception catch (e) {
      await pushLog('Error in batchEnrollStudents: $e');
      return DataFailed<Map<String, dynamic>>(e.toString());
    }
  }

  @override
  Future<DataState<List<Map<String, dynamic>>>> getAvailableStudents(
      String courseId, {int? limit, int? offset}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (limit != null) queryParams['limit'] = limit;
      if (offset != null) queryParams['skip'] = offset;

      final response = await _apiClient.get(
        path: '${ApiEndpoint.courses}/$courseId/available-students',
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );
      if (response.isSuccess()) {
        final json = response.data as Map<String, dynamic>;
        final students = json['students'] as List<dynamic>;
        return DataSuccess<List<Map<String, dynamic>>>(
          students.map((e) => e as Map<String, dynamic>).toList(),
        );
      }
      return DataFailed<List<Map<String, dynamic>>>(response.error);
    } on DioError catch (e) {
      await pushLog('Error in getAvailableStudents: $e');
      return DataFailed<List<Map<String, dynamic>>>(e.message);
    } on Exception catch (e) {
      await pushLog('Error in getAvailableStudents: $e');
      return DataFailed<List<Map<String, dynamic>>>(e.toString());
    }
  }

  @override
  Future<DataState<void>> unenrollStudent(
      String courseId, int studentId) async {
    try {
      final response = await _apiClient.delete(
        path: '${ApiEndpoint.courses}/$courseId/students/$studentId',
      );
      if (response.isSuccess()) {
        return const DataSuccess<void>(null);
      }
      return DataFailed<void>(response.error);
    } on DioError catch (e) {
      await pushLog('Error in unenrollStudent: $e');
      return DataFailed<void>(e.message);
    } on Exception catch (e) {
      await pushLog('Error in unenrollStudent: $e');
      return DataFailed<void>(e.toString());
    }
  }
}
