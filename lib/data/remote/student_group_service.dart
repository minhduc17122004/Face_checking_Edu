import 'package:dio/dio.dart';
import 'package:face_time_keeping/common/utils/log_util.dart';
import 'package:injectable/injectable.dart';

import '../../common/api_client/api_client.dart';
import '../../common/api_client/api_response.dart';
import '../../common/api_client/data_state.dart';
import '../../entities/student_group.dart';
import 'api_endpoint.dart';

abstract class StudentGroupService {
  Future<DataState<List<StudentGroup>>> getStudentGroups({
    int? limit,
    int? offset,
    String? code,
    String? departmentId,
  });
  Future<DataState<StudentGroup>> createStudentGroup({
    String? code,
    String? name,
    String? departmentId,
    String? advisorId,
  });
  Future<DataState<StudentGroup>> updateStudentGroup(
    String id, {
    String? code,
    String? name,
    String? departmentId,
    String? advisorId,
  });
  Future<DataState<void>> deleteStudentGroup(String id);
}

@LazySingleton(as: StudentGroupService)
class StudentGroupServiceImplement implements StudentGroupService {
  StudentGroupServiceImplement(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<DataState<List<StudentGroup>>> getStudentGroups({
    int? limit,
    int? offset,
    String? code,
    String? departmentId,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (limit != null) queryParams['limit'] = limit;
      if (offset != null) queryParams['skip'] = offset;
      if (code != null && code.trim().isNotEmpty) {
        queryParams['code'] = code.trim();
      }
      if (departmentId != null && departmentId.trim().isNotEmpty) {
        queryParams['department_id'] = departmentId.trim();
      }

      final ApiResponse response = await _apiClient.get(
        path: ApiEndpoint.studentGroups,
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      if (response.isSuccess()) {
        final json = response.data as Map<String, dynamic>;
        final items = (json['items'] as List<dynamic>? ?? const []);
        final groups = items
            .map((e) => StudentGroup.fromJson(e as Map<String, dynamic>))
            .toList();
        return DataSuccess<List<StudentGroup>>(groups);
      }
      return DataFailed<List<StudentGroup>>(response.error);
    } on DioError catch (e) {
      await pushLog('Error in getStudentGroups: $e');
      return DataFailed<List<StudentGroup>>(e.message);
    } on Exception catch (e) {
      await pushLog('Error in getStudentGroups: $e');
      return DataFailed<List<StudentGroup>>(e.toString());
    }
  }

  @override
  Future<DataState<StudentGroup>> createStudentGroup({
    String? code,
    String? name,
    String? departmentId,
    String? advisorId,
  }) async {
    try {
      final response = await _apiClient.post(
        path: ApiEndpoint.studentGroups,
        data: {
          'code': code,
          if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
          if (departmentId != null && departmentId.trim().isNotEmpty)
            'department_id': departmentId.trim(),
          if (advisorId != null && advisorId.trim().isNotEmpty)
            'advisor_id': advisorId.trim(),
        },
      );
      if (response.isSuccess()) {
        return DataSuccess<StudentGroup>(
          StudentGroup.fromJson(response.data as Map<String, dynamic>),
        );
      }
      return DataFailed<StudentGroup>(response.error);
    } on DioError catch (e) {
      await pushLog('Error in createStudentGroup: $e');
      return DataFailed<StudentGroup>(e.message);
    } on Exception catch (e) {
      await pushLog('Error in createStudentGroup: $e');
      return DataFailed<StudentGroup>(e.toString());
    }
  }

  @override
  Future<DataState<StudentGroup>> updateStudentGroup(
    String id, {
    String? code,
    String? name,
    String? departmentId,
    String? advisorId,
  }) async {
    try {
      final response = await _apiClient.patch(
        path: '${ApiEndpoint.studentGroups}/$id',
        data: {
          if (code != null && code.trim().isNotEmpty) 'code': code.trim(),
          if (name != null) 'name': name.trim().isEmpty ? null : name.trim(),
          if (departmentId != null)
            'department_id':
                departmentId.trim().isEmpty ? null : departmentId.trim(),
          if (advisorId != null)
            'advisor_id': advisorId.trim().isEmpty ? null : advisorId.trim(),
        },
      );
      if (response.isSuccess()) {
        return DataSuccess<StudentGroup>(
          StudentGroup.fromJson(response.data as Map<String, dynamic>),
        );
      }
      return DataFailed<StudentGroup>(response.error);
    } on DioError catch (e) {
      await pushLog('Error in updateStudentGroup: $e');
      return DataFailed<StudentGroup>(e.message);
    } on Exception catch (e) {
      await pushLog('Error in updateStudentGroup: $e');
      return DataFailed<StudentGroup>(e.toString());
    }
  }

  @override
  Future<DataState<void>> deleteStudentGroup(String id) async {
    try {
      final response = await _apiClient.delete(
        path: '${ApiEndpoint.studentGroups}/$id',
      );
      if (response.isSuccess()) {
        return const DataSuccess<void>(null);
      }
      return DataFailed<void>(response.error);
    } on DioError catch (e) {
      await pushLog('Error in deleteStudentGroup: $e');
      return DataFailed<void>(e.message);
    } on Exception catch (e) {
      await pushLog('Error in deleteStudentGroup: $e');
      return DataFailed<void>(e.toString());
    }
  }
}
