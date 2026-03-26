import 'package:dio/dio.dart';
import 'package:face_time_keeping/common/utils/log_util.dart';
import 'package:injectable/injectable.dart';

import '../../common/api_client/api_client.dart';
import '../../common/api_client/api_response.dart';
import '../../common/api_client/data_state.dart';
import '../../entities/device_request.dart';
import 'api_endpoint.dart';

abstract class DeviceRequestService {
  Future<DataState<DeviceRequest>> submitRequest({
    required String deviceCode,
    String? deviceName,
    String? roomId,
  });
  Future<DataState<List<DeviceRequest>>> getMyRequests(String deviceCode);
  Future<DataState<List<DeviceRequest>>> getAllRequests({
    String? status,
    int skip = 0,
    int limit = 100,
  });
  Future<DataState<DeviceRequest>> getRequest(String id);
  Future<DataState<DeviceRequest>> approveRequest(String id, {String? adminNote});
  Future<DataState<DeviceRequest>> rejectRequest(String id, {String? adminNote});
}

@LazySingleton(as: DeviceRequestService)
class DeviceRequestServiceImplement implements DeviceRequestService {
  DeviceRequestServiceImplement(this._apiClient);
  final ApiClient _apiClient;

  @override
  Future<DataState<DeviceRequest>> submitRequest({
    required String deviceCode,
    String? deviceName,
    String? roomId,
  }) async {
    try {
      final response = await _apiClient.post(
        path: ApiEndpoint.deviceRequests,
        data: {
          'device_code': deviceCode,
          if (deviceName != null) 'device_name': deviceName,
          if (roomId != null) 'room_id': roomId,
        },
      );
      if (response.isSuccess()) {
        return DataSuccess<DeviceRequest>(
          DeviceRequest.fromJson(response.data as Map<String, dynamic>),
        );
      }
      return DataFailed<DeviceRequest>(response.error);
    } on DioError catch (e) {
      await pushLog('Error in submitRequest: $e');
      return DataFailed<DeviceRequest>(e.message);
    } on Exception catch (e) {
      await pushLog('Error in submitRequest: $e');
      return DataFailed<DeviceRequest>(e.toString());
    }
  }

  @override
  Future<DataState<List<DeviceRequest>>> getMyRequests(String deviceCode) async {
    try {
      final response = await _apiClient.get(
        path: ApiEndpoint.deviceRequestsMe,
        queryParameters: {'device_code': deviceCode},
      );
      if (response.isSuccess()) {
        final json = response.data as Map<String, dynamic>;
        final items = json['items'] as List<dynamic>? ?? [];
        return DataSuccess<List<DeviceRequest>>(
          items.map((e) => DeviceRequest.fromJson(e as Map<String, dynamic>)).toList(),
        );
      }
      return DataFailed<List<DeviceRequest>>(response.error);
    } on DioError catch (e) {
      await pushLog('Error in getMyRequests: $e');
      return DataFailed<List<DeviceRequest>>(e.message);
    } on Exception catch (e) {
      await pushLog('Error in getMyRequests: $e');
      return DataFailed<List<DeviceRequest>>(e.toString());
    }
  }

  @override
  Future<DataState<List<DeviceRequest>>> getAllRequests({
    String? status,
    int skip = 0,
    int limit = 100,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'skip': skip,
        'limit': limit,
      };
      if (status != null) queryParams['status'] = status;

      final response = await _apiClient.get(
        path: ApiEndpoint.deviceRequests,
        queryParameters: queryParams,
      );
      if (response.isSuccess()) {
        final json = response.data as Map<String, dynamic>;
        final items = json['items'] as List<dynamic>? ?? [];
        return DataSuccess<List<DeviceRequest>>(
          items.map((e) => DeviceRequest.fromJson(e as Map<String, dynamic>)).toList(),
        );
      }
      return DataFailed<List<DeviceRequest>>(response.error);
    } on DioError catch (e) {
      await pushLog('Error in getAllRequests: $e');
      return DataFailed<List<DeviceRequest>>(e.message);
    } on Exception catch (e) {
      await pushLog('Error in getAllRequests: $e');
      return DataFailed<List<DeviceRequest>>(e.toString());
    }
  }

  @override
  Future<DataState<DeviceRequest>> getRequest(String id) async {
    try {
      final response = await _apiClient.get(path: '${ApiEndpoint.deviceRequests}$id');
      if (response.isSuccess()) {
        return DataSuccess<DeviceRequest>(
          DeviceRequest.fromJson(response.data as Map<String, dynamic>),
        );
      }
      return DataFailed<DeviceRequest>(response.error);
    } on DioError catch (e) {
      await pushLog('Error in getRequest: $e');
      return DataFailed<DeviceRequest>(e.message);
    } on Exception catch (e) {
      await pushLog('Error in getRequest: $e');
      return DataFailed<DeviceRequest>(e.toString());
    }
  }

  @override
  Future<DataState<DeviceRequest>> approveRequest(String id, {String? adminNote}) async {
    try {
      final response = await _apiClient.patch(
        path: '${ApiEndpoint.deviceRequests}$id/approve',
        data: {
          if (adminNote != null) 'admin_note': adminNote,
        },
      );
      if (response.isSuccess()) {
        return DataSuccess<DeviceRequest>(
          DeviceRequest.fromJson(response.data as Map<String, dynamic>),
        );
      }
      return DataFailed<DeviceRequest>(response.error);
    } on DioError catch (e) {
      await pushLog('Error in approveRequest: $e');
      return DataFailed<DeviceRequest>(e.message);
    } on Exception catch (e) {
      await pushLog('Error in approveRequest: $e');
      return DataFailed<DeviceRequest>(e.toString());
    }
  }

  @override
  Future<DataState<DeviceRequest>> rejectRequest(String id, {String? adminNote}) async {
    try {
      final response = await _apiClient.patch(
        path: '${ApiEndpoint.deviceRequests}$id/reject',
        data: {
          if (adminNote != null) 'admin_note': adminNote,
        },
      );
      if (response.isSuccess()) {
        return DataSuccess<DeviceRequest>(
          DeviceRequest.fromJson(response.data as Map<String, dynamic>),
        );
      }
      return DataFailed<DeviceRequest>(response.error);
    } on DioError catch (e) {
      await pushLog('Error in rejectRequest: $e');
      return DataFailed<DeviceRequest>(e.message);
    } on Exception catch (e) {
      await pushLog('Error in rejectRequest: $e');
      return DataFailed<DeviceRequest>(e.toString());
    }
  }
}
