import 'message_parser.dart';

class ApiResponse {
  ApiResponse({this.success, this.data, this.status, this.error});

  ApiResponse.fromJson(Map<String?, dynamic> json) {
    data = json;
    status = json['Status'];
    success =
        json['success'] ?? json['error'] == null && json['error_code'] == null;
    if (messageParser[json['error_code']] != null) {
      error = messageParser[json['error_code']];
    } else {
      final errorJson = json['error'];
      if (errorJson is Map<String, dynamic>) {
        data = errorJson['data'];
        error = data['message'] ?? "Lỗi";
      } else if (errorJson is String) {
        error = errorJson;
      }
    }
  }

  bool? success;
  dynamic data;
  String? status;
  String? error;

  bool isSuccess() => success ?? false;
}
