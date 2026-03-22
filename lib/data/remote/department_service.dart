import 'package:dio/dio.dart';
import 'package:face_time_keeping/common/utils/log_util.dart';
import 'package:injectable/injectable.dart';

import '../../common/api_client/api_client.dart';
import '../../common/api_client/api_response.dart';
import '../../common/api_client/data_state.dart';
import '../../entities/department.dart';
import 'api_endpoint.dart';

abstract class DepartmentService {
  Future<DataState<List<Department>>> getDepartments();
  Future<DataState<Department>> getDepartment(String id);
  Future<DataState<Department>> createDepartment({
    required String code,
    required String name,
  });
  Future<DataState<Department>> updateDepartment(
    String id, {
    String? code,
    String? name,
  });
  Future<DataState<void>> deleteDepartment(String id);
}

@LazySingleton(as: DepartmentService)
class DepartmentServiceImplement implements DepartmentService {
  DepartmentServiceImplement(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<DataState<List<Department>>> getDepartments() async {
    try {
      final response = await _apiClient.get(path: ApiEndpoint.departments);
      if (response.isSuccess()) {
        final json = response.data as Map<String, dynamic>;
        final items = json['items'] as List<dynamic>;
        final departments = items
            .map((e) => Department.fromJson(e as Map<String, dynamic>))
            .toList();
        return DataSuccess<List<Department>>(departments);
      }
      return DataFailed<List<Department>>(response.error);
    } on DioError catch (e) {
      await pushLog('Error in getDepartments: $e');
      return DataFailed<List<Department>>(e.message);
    } on Exception catch (e) {
      await pushLog('Error in getDepartments: $e');
      return DataFailed<List<Department>>(e.toString());
    }
  }

  @override
  Future<DataState<Department>> getDepartment(String id) async {
    try {
      final response =
          await _apiClient.get(path: '${ApiEndpoint.departments}/$id');
      if (response.isSuccess()) {
        return DataSuccess<Department>(
          Department.fromJson(response.data as Map<String, dynamic>),
        );
      }
      return DataFailed<Department>(response.error);
    } on DioError catch (e) {
      await pushLog('Error in getDepartment: $e');
      return DataFailed<Department>(e.message);
    } on Exception catch (e) {
      await pushLog('Error in getDepartment: $e');
      return DataFailed<Department>(e.toString());
    }
  }

  @override
  Future<DataState<Department>> createDepartment({
    required String code,
    required String name,
  }) async {
    try {
      final response = await _apiClient.post(
        path: ApiEndpoint.departments,
        data: {
          'code': code,
          'name': name,
        },
      );
      if (response.isSuccess()) {
        return DataSuccess<Department>(
          Department.fromJson(response.data as Map<String, dynamic>),
        );
      }
      return DataFailed<Department>(response.error);
    } on DioError catch (e) {
      await pushLog('Error in createDepartment: $e');
      return DataFailed<Department>(e.message);
    } on Exception catch (e) {
      await pushLog('Error in createDepartment: $e');
      return DataFailed<Department>(e.toString());
    }
  }

  @override
  Future<DataState<Department>> updateDepartment(
    String id, {
    String? code,
    String? name,
  }) async {
    try {
      final response = await _apiClient.put(
        path: '${ApiEndpoint.departments}/$id',
        data: {
          if (code != null) 'code': code,
          if (name != null) 'name': name,
        },
      );
      if (response.isSuccess()) {
        return DataSuccess<Department>(
          Department.fromJson(response.data as Map<String, dynamic>),
        );
      }
      return DataFailed<Department>(response.error);
    } on DioError catch (e) {
      await pushLog('Error in updateDepartment: $e');
      return DataFailed<Department>(e.message);
    } on Exception catch (e) {
      await pushLog('Error in updateDepartment: $e');
      return DataFailed<Department>(e.toString());
    }
  }

  @override
  Future<DataState<void>> deleteDepartment(String id) async {
    try {
      final response =
          await _apiClient.delete(path: '${ApiEndpoint.departments}/$id');
      if (response.isSuccess()) {
        return const DataSuccess<void>(null);
      }
      return DataFailed<void>(response.error);
    } on DioError catch (e) {
      await pushLog('Error in deleteDepartment: $e');
      return DataFailed<void>(e.message);
    } on Exception catch (e) {
      await pushLog('Error in deleteDepartment: $e');
      return DataFailed<void>(e.toString());
    }
  }
}
