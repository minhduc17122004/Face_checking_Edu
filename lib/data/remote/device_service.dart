import 'package:dio/dio.dart';
import 'package:face_time_keeping/common/utils/log_util.dart';
import 'package:injectable/injectable.dart';

import '../../common/api_client/api_client.dart';
import '../../common/api_client/data_state.dart';
import '../../entities/device.dart';
import 'api_endpoint.dart';

abstract class DeviceService {
  Future<DataState<Device>> registerDevice({
    required String deviceCode,
    String? deviceName,
    String? roomId,
    bool isGlobal = false,
    bool isActive = true,
    String? deviceType,
    String? ipAddress,
  });
  Future<DataState<Device>> getDevice(String id);
  Future<DataState<Device>> updateDevice(
    String id, {
    String? roomId,
    bool? isActive,
    bool? isGlobal,
    String? status,
    String? deviceType,
    String? ipAddress,
  });
  Future<DataState<List<Device>>> getDevices({int skip = 0, int limit = 100});
}

@LazySingleton(as: DeviceService)
class DeviceServiceImplement implements DeviceService {
  DeviceServiceImplement(this._apiClient);
  final ApiClient _apiClient;

  @override
  Future<DataState<Device>> registerDevice({
    required String deviceCode,
    String? deviceName,
    String? roomId,
    bool isGlobal = false,
    bool isActive = true,
    String? deviceType,
    String? ipAddress,
  }) async {
    try {
      final response = await _apiClient.post(
        path: ApiEndpoint.devices,
        data: {
          'device_code': deviceCode,
          if (deviceName != null) 'device_name': deviceName,
          if (roomId != null) 'room_id': roomId,
          'is_global': isGlobal,
          'is_active': isActive,
          if (deviceType != null) 'device_type': deviceType,
          if (ipAddress != null) 'ip_address': ipAddress,
        },
      );
      if (response.isSuccess()) {
        return DataSuccess<Device>(
          Device.fromJson(response.data as Map<String, dynamic>),
        );
      }
      return DataFailed<Device>(response.error);
    } on DioError catch (e) {
      await pushLog('Error in registerDevice: $e');
      return DataFailed<Device>(e.message);
    } on Exception catch (e) {
      await pushLog('Error in registerDevice: $e');
      return DataFailed<Device>(e.toString());
    }
  }

  @override
  Future<DataState<Device>> getDevice(String id) async {
    try {
      final response = await _apiClient.get(path: '${ApiEndpoint.devices}$id');
      if (response.isSuccess()) {
        return DataSuccess<Device>(
          Device.fromJson(response.data as Map<String, dynamic>),
        );
      }
      return DataFailed<Device>(response.error);
    } on DioError catch (e) {
      await pushLog('Error in getDevice: $e');
      return DataFailed<Device>(e.message);
    } on Exception catch (e) {
      await pushLog('Error in getDevice: $e');
      return DataFailed<Device>(e.toString());
    }
  }

  @override
  Future<DataState<Device>> updateDevice(
    String id, {
    String? roomId,
    bool? isActive,
    bool? isGlobal,
    String? status,
    String? deviceType,
    String? ipAddress,
  }) async {
    try {
      final response = await _apiClient.patch(
        path: '${ApiEndpoint.devices}$id',
        data: {
          if (roomId != null) 'room_id': roomId,
          if (isActive != null) 'is_active': isActive,
          if (isGlobal != null) 'is_global': isGlobal,
          if (status != null) 'status': status,
          if (deviceType != null) 'device_type': deviceType,
          if (ipAddress != null) 'ip_address': ipAddress,
        },
      );
      if (response.isSuccess()) {
        return DataSuccess<Device>(
          Device.fromJson(response.data as Map<String, dynamic>),
        );
      }
      return DataFailed<Device>(response.error);
    } on DioError catch (e) {
      await pushLog('Error in updateDevice: $e');
      return DataFailed<Device>(e.message);
    } on Exception catch (e) {
      await pushLog('Error in updateDevice: $e');
      return DataFailed<Device>(e.toString());
    }
  }

  @override
  Future<DataState<List<Device>>> getDevices({int skip = 0, int limit = 100}) async {
    try {
      final response = await _apiClient.get(
        path: ApiEndpoint.devices,
        queryParameters: {'skip': skip, 'limit': limit},
      );
      if (response.isSuccess()) {
        final json = response.data as Map<String, dynamic>;
        final items = json['items'] as List<dynamic>? ?? [];
        return DataSuccess<List<Device>>(
          items.map((e) => Device.fromJson(e as Map<String, dynamic>)).toList(),
        );
      }
      return DataFailed<List<Device>>(response.error);
    } on DioError catch (e) {
      await pushLog('Error in getDevices: $e');
      return DataFailed<List<Device>>(e.message);
    } on Exception catch (e) {
      await pushLog('Error in getDevices: $e');
      return DataFailed<List<Device>>(e.toString());
    }
  }
}
