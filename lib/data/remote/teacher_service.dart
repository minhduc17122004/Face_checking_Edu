import 'package:dio/dio.dart';
import 'package:face_time_keeping/common/utils/log_util.dart';
import 'package:injectable/injectable.dart';

import '../../common/api_client/api_client.dart';
import '../../common/api_client/api_response.dart';
import '../../common/api_client/data_state.dart';
import '../../entities/teacher.dart';
import 'api_endpoint.dart';

abstract class TeacherService {
  Future<DataState<List<Teacher>>> getTeachers({
    String? departmentId,
    int? limit,
    int? offset,
  });
  Future<DataState<Teacher>> getTeacher(int id);
  Future<DataState<Teacher>> assignDepartment(
      int teacherId, String departmentId);
  Future<DataState<Teacher>> removeDepartment(int teacherId);
}

@LazySingleton(as: TeacherService)
class TeacherServiceImplement implements TeacherService {
  TeacherServiceImplement(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<DataState<List<Teacher>>> getTeachers({
    String? departmentId,
    int? limit,
    int? offset,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (departmentId != null) queryParams['department_id'] = departmentId;
      if (limit != null) queryParams['limit'] = limit;
      if (offset != null) queryParams['skip'] = offset;

      final ApiResponse response = await _apiClient.get(
        path: ApiEndpoint.teachers,
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );
      if (response.isSuccess()) {
        final json = response.data as Map<String, dynamic>;
        final items = json['items'] as List<dynamic>;
        final teachers = items
            .map((e) => Teacher.fromJson(e as Map<String, dynamic>))
            .toList();
        return DataSuccess<List<Teacher>>(teachers);
      }
      return DataFailed<List<Teacher>>(response.error);
    } on DioError catch (e) {
      await pushLog('Error in getTeachers: $e');
      return DataFailed<List<Teacher>>(e.message);
    } on Exception catch (e) {
      await pushLog('Error in getTeachers: $e');
      return DataFailed<List<Teacher>>(e.toString());
    }
  }

  @override
  Future<DataState<Teacher>> getTeacher(int id) async {
    try {
      final response =
          await _apiClient.get(path: '${ApiEndpoint.teachers}/$id');
      if (response.isSuccess()) {
        return DataSuccess<Teacher>(
          Teacher.fromJson(response.data as Map<String, dynamic>),
        );
      }
      return DataFailed<Teacher>(response.error);
    } on DioError catch (e) {
      await pushLog('Error in getTeacher: $e');
      return DataFailed<Teacher>(e.message);
    } on Exception catch (e) {
      await pushLog('Error in getTeacher: $e');
      return DataFailed<Teacher>(e.toString());
    }
  }

  @override
  Future<DataState<Teacher>> assignDepartment(
      int teacherId, String departmentId) async {
    try {
      final response = await _apiClient.post(
        path: ApiEndpoint.teacherAssignDepartment
            .replaceFirst('{id}', teacherId.toString()),
        data: {'department_id': departmentId},
      );
      if (response.isSuccess()) {
        return DataSuccess<Teacher>(
          Teacher.fromJson(response.data as Map<String, dynamic>),
        );
      }
      return DataFailed<Teacher>(response.error);
    } on DioError catch (e) {
      await pushLog('Error in assignDepartment: $e');
      return DataFailed<Teacher>(e.message);
    } on Exception catch (e) {
      await pushLog('Error in assignDepartment: $e');
      return DataFailed<Teacher>(e.toString());
    }
  }

  @override
  Future<DataState<Teacher>> removeDepartment(int teacherId) async {
    try {
      final response = await _apiClient.delete(
        path: ApiEndpoint.teacherAssignDepartment
            .replaceFirst('{id}', teacherId.toString()),
      );
      if (response.isSuccess()) {
        return DataSuccess<Teacher>(
          Teacher.fromJson(response.data as Map<String, dynamic>),
        );
      }
      return DataFailed<Teacher>(response.error);
    } on DioError catch (e) {
      await pushLog('Error in removeDepartment: $e');
      return DataFailed<Teacher>(e.message);
    } on Exception catch (e) {
      await pushLog('Error in removeDepartment: $e');
      return DataFailed<Teacher>(e.toString());
    }
  }
}
