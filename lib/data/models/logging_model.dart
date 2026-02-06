class DeviceInfo {
  final String model;
  final String device_type;
  final String os_version;
  
  const DeviceInfo({
    required this.model,
    required this.device_type,
    required this.os_version,
  });

  factory DeviceInfo.fromJson(Map<String, dynamic> json) {
    return DeviceInfo(
      model: json['model'] ?? '',
      device_type: json['device_type'] ?? '',
      os_version: json['os_version'] ?? '',
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'model': model,
      'device_type': device_type,
      'os_version': os_version,
    };
  }
}

class LoggingApiResponse {
  final int? status_code;
  final String message;
  final int? error_code;
  
  const LoggingApiResponse({
    this.status_code,
    required this.message,
    this.error_code,
  });

  factory LoggingApiResponse.fromJson(Map<String, dynamic> json) {
    return LoggingApiResponse(
      status_code: json['status_code'] ?? 0,
      message: json['message'] ?? '',
      error_code: json['error_code'] ?? 0,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'status_code': status_code,
      'message': message,
      'error_code': error_code,
    };
  }
}

class ApiInfo {

  final LoggingApiResponse response;
  
  const ApiInfo({


    required this.response,
  });

  factory ApiInfo.fromJson(Map<String, dynamic> json) {
    return ApiInfo(
      response: LoggingApiResponse.fromJson(json['response'] ?? {}),
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'response': response.toJson(),
    };
  }
}

class LoggingModel {
  final String app_name;
  final String log_level;
  final DeviceInfo device_info;
  final ApiInfo api_info;
  final int user_id;
  final String timestamp_local;
  final String timestamp_utc;
  
  const LoggingModel({
    this.app_name="Chấm Công",
    this.log_level="ERROR",
    required this.device_info,
    required this.api_info,
    required this.user_id,
    required this.timestamp_local,
    required this.timestamp_utc,
  });

  factory LoggingModel.fromJson(Map<String, dynamic> json) {
    return LoggingModel(
      app_name: json['app_name'] ?? '',
      log_level: json['log_level'] ?? '',
      device_info: DeviceInfo.fromJson(json['device_info'] ?? {}),
      api_info: ApiInfo.fromJson(json['api_info'] ?? {}),
      user_id: json['user_id'] ?? 0,
      timestamp_local: json['timestamp_local'] ?? '',
      timestamp_utc: json['timestamp_utc'] ?? '',
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'app_name': app_name,
      'log_level': log_level,
      'device_info': device_info.toJson(),
      'api_info': api_info.toJson(),
      'user_id': user_id,
      'timestamp_local': timestamp_local,
      'timestamp_utc': timestamp_utc,
    };
  }
}