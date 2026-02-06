import 'package:device_info_plus/device_info_plus.dart';
import 'package:face_time_keeping/common/api_client/api_response.dart';
import 'package:face_time_keeping/data/local/local_service.dart';
import 'package:face_time_keeping/data/remote/api_endpoint.dart';
import 'package:injectable/injectable.dart';

import '../../common/api_client/api_client.dart';
import '../models/logging_model.dart';

abstract class LoggingService {
  Future<String> log(ApiInfo api_info, {String? url});
  //Future<String> testLog();
}

@LazySingleton(as: LoggingService)
class LoggingServiceImplement extends LoggingService {
  LoggingServiceImplement(this._apiClient, this._localService);

  final ApiClient _apiClient;
  final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
  final LocalService _localService;
  @override
  Future<String> log(ApiInfo api_info, {String? url}) async {
    try {
      final androidInfo = await deviceInfo.androidInfo;
      final userId = await _localService.getUserId();
      final loggingModel = LoggingModel(
        app_name: "Chấm Công",
        log_level: "ERROR",
        device_info: DeviceInfo(
          model: androidInfo.model,
          device_type: androidInfo.device,
          os_version: androidInfo.version.release,
        ),
        api_info: api_info,
        user_id: userId ?? 0,
        timestamp_local: DateTime.now().toString().split('.').first,
        timestamp_utc: DateTime.now().toUtc().toString().split('.').first,
      );
      final ApiResponse response = await _apiClient.post(
        path: "${url ?? ''}${ApiEndpoint.logging}",
        data: loggingModel.toJson(),
      );
      if (response.isSuccess()) {
        return response.data['message'];
      }
      return response.error ?? 'Logging thất bại';
    } catch (e, stackTrace) {
      // Optionally log the error and stack trace for debugging
      // log('LoggingServiceImplement.log error: $e\n$stackTrace');
      rethrow;
    }
  }
}
