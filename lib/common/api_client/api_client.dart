import 'dart:convert';
import 'dart:io';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:face_time_keeping/common/api_client/interceptors/cookie_interceptor.dart';
import 'package:face_time_keeping/common/api_client/interceptors/curl_logger_interceptor.dart';
import 'package:face_time_keeping/common/utils/log_util.dart';
import 'package:face_time_keeping/data/remote/api_endpoint.dart';
import 'package:flutter/material.dart';
import 'package:injectable/injectable.dart';
import '../../configs/build_config.dart';
import '../../di/injection.dart';
import '../resources/asset_strings.dart';
import 'api_response.dart';
import 'interceptors/auth_interceptor.dart';

@singleton
class ApiClient {
  ApiClient({required this.dio, required AuthInterceptor authInterceptor}) {
    late final cookieJar;
    final BuildConfig buildConfig = getIt<BuildConfig>();
    dio.options.baseUrl = buildConfig.kBaseUrl;
    cookieJar = CookieJar();
    dio.interceptors.add(authInterceptor);
    dio.interceptors.add(CookieInterceptor(cookieJar));
    dio.interceptors.add(CurlLoggerDioInterceptor());
    //  dio.interceptors.add(LoggingInterceptor());
    if (buildConfig.debugLog) {
      dio.interceptors
          .add(LogInterceptor(responseBody: true, requestBody: true));
    }
    _config();
  }
  void _config() {
    // dio.options.headersCaseSensitive = true;
    dio.options.headers['Content-Type'] = 'application/json';
    dio.options.headers['Accept'] = 'application/json';
    dio.options.headers['client-id'] = Platform.isAndroid ? 'Android' : 'iOS';
    dio.options.connectTimeout = const Duration(seconds: 20).inMilliseconds;
    dio.options.receiveTimeout = const Duration(seconds: 20).inMilliseconds;
  }

  final _defaultHeaders = {
    "Content-Type": "application/json",
    'Accept': 'application/json',
  };

  final Dio dio;

  static const String _missingBaseUrlMessage =
      'Chua cau hinh API_BASE_URL. Vui long set dart-define API_BASE_URL truoc khi thuc hien thao tac nay.';

  void updateConfigBaseUrl(String url) {
    dio.options.baseUrl = url;
  }

  bool _isAbsoluteUrl(String path) {
    final uri = Uri.tryParse(path);
    return uri != null && uri.isAbsolute && uri.hasAuthority;
  }

  bool _hasValidBaseUrl() {
    final uri = Uri.tryParse(dio.options.baseUrl);
    return uri != null && uri.isAbsolute && uri.hasAuthority;
  }

  ApiResponse _missingBaseUrlResponse() {
    return ApiResponse(
      success: false,
      status: 'error',
      error: _missingBaseUrlMessage,
    );
  }

  Future<ApiResponse> _requestWithBaseUrlGuard(
      String path, Future<ApiResponse> Function() request) async {
    if (!_isAbsoluteUrl(path) && !_hasValidBaseUrl()) {
      return _missingBaseUrlResponse();
    }
    return request();
  }

  Future<ApiResponse> post({
    required String path,
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
    ProgressCallback? onSendProgress,
    CancelToken? cancelToken,
    Duration? sendTimeout,
    Duration? receiveTimeout,
  }) async {
    return _requestWithBaseUrlGuard(
      path,
      () => responseWrapper(dio.post<dynamic>(
        path,
        data: data,
        queryParameters: queryParameters,
        onSendProgress: onSendProgress,
        cancelToken: cancelToken,
        options: Options(
          headers: headers ?? _defaultHeaders,
          sendTimeout: sendTimeout?.inMilliseconds,
          receiveTimeout: receiveTimeout?.inMilliseconds,
        ),
      )),
    );
  }

  Future<ApiResponse> put({
    required String path,
    dynamic data,
    Map<String, dynamic>? headers,
    Duration? sendTimeout,
    Duration? receiveTimeout,
  }) async {
    return _requestWithBaseUrlGuard(
      path,
      () => responseWrapper(dio.put<dynamic>(
        path,
        data: data,
        options: Options(
          headers: headers ?? {},
          sendTimeout: sendTimeout?.inMilliseconds,
          receiveTimeout: receiveTimeout?.inMilliseconds,
        ),
      )),
    );
  }

  Future<ApiResponse> patch({
    required String path,
    dynamic data,
    Duration? sendTimeout,
    Duration? receiveTimeout,
  }) async {
    return _requestWithBaseUrlGuard(
      path,
      () => responseWrapper(dio.patch<dynamic>(
        path,
        data: data,
        options: Options(
          sendTimeout: sendTimeout?.inMilliseconds,
          receiveTimeout: receiveTimeout?.inMilliseconds,
        ),
      )),
    );
  }

  Future<ApiResponse> delete({
    required String path,
    dynamic data,
    Duration? sendTimeout,
    Duration? receiveTimeout,
  }) async {
    return _requestWithBaseUrlGuard(
      path,
      () => responseWrapper(dio.delete<dynamic>(
        path,
        data: data,
        options: Options(
          sendTimeout: sendTimeout?.inMilliseconds,
          receiveTimeout: receiveTimeout?.inMilliseconds,
        ),
      )),
    );
  }

  Future<ApiResponse> get({
    required String path,
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
    Duration? sendTimeout,
    Duration? receiveTimeout,
  }) async {
    return _requestWithBaseUrlGuard(
      path,
      () => responseWrapper(dio.request<dynamic>(
        path,
        queryParameters: queryParameters,
        options: Options(
          method: "GET",
          headers: {
            "Content-Type": "application/json",
            "Accept": "application/json",
            ...?headers,
          },
          sendTimeout: sendTimeout?.inMilliseconds,
          receiveTimeout: receiveTimeout?.inMilliseconds,
        ),
        data: data,
      )),
    );
  }

  Future<ApiResponse> download(
      {required String path,
      required String savePath,
      ProgressCallback? onReceiveProgress}) async {
    try {
      if (!_isAbsoluteUrl(path) && !_hasValidBaseUrl()) {
        return _missingBaseUrlResponse();
      }
      await dio.download(path, savePath, onReceiveProgress: onReceiveProgress);
      return ApiResponse(success: true);
    } on DioError catch (e) {
      return _handleRequestError(e);
    }
  }

  Future<ApiResponse> responseWrapper(Future<Response<dynamic>> func) async {
    try {
      final Response<dynamic> response = await func;
      if (response.statusCode == 204 || response.data == null || response.data.toString().trim().isEmpty) {
        return ApiResponse(success: true, data: {});
      }
      if (response.data is List) {
        return ApiResponse(success: true, data: response.data);
      }

      Map<String?, dynamic>? decode;

      if (response.data is Map<String, dynamic>) {
        decode = response.data as Map<String?, dynamic>;
      } else {
        try {
          decode = json.decode(response.data.toString()) as Map<String?, dynamic>;
        } catch (_) {
          return ApiResponse(
            success: true,
            data: response.data,
          );
        }
      }

      if (decode is Map<String?, dynamic>) {
        return ApiResponse.fromJson(decode);
      }
      return ApiResponse(
        success: false,
        status: 'error',
        error: Strings.localized.somethingWentWrong,
      );
    } on DioError catch (e) {
      debugPrint('API error: ${e.message}');
      final response = e.response?.data;
      if (response is Map<String, dynamic>) {
        dynamic errObj = response['error'] ?? response['detail'];
        String errStr = Strings.localized.somethingWentWrong;
        if (errObj is String) {
          errStr = errObj;
        } else if (errObj is List && errObj.isNotEmpty) {
          final firstErr = errObj[0];
          if (firstErr is Map && firstErr['msg'] != null) {
            errStr = firstErr['msg'].toString();
          } else {
            errStr = errObj.toString();
          }
        } else if (errObj != null) {
          errStr = errObj.toString();
        }
        return ApiResponse(
          success: false,
          status: 'error',
          error: errStr,
        );
      }
      return await _handleRequestError(e);
    } catch (e) {
      debugPrint('Unhandled API Exception: $e');
      return ApiResponse(
        success: false,         
        status: 'error',
        error: Strings.localized.somethingWentWrong,
      );
    }
  }

//   Future<void> _logApiError(DioError e) async {
//   try {
//     final apiInfo = ApiInfo(
//       path: e.requestOptions.path,
//       method: e.requestOptions.method,
//       request: e.requestOptions.data ?? {},
//       response: LoggingApiResponse(
//         status_code: e.response?.statusCode ?? 0,
//         message: e.message ,
//         error_code: e.response?.statusCode ?? 0,
//       ),
//     );
//     await loggingService.log(apiInfo);
//   } catch (logError) {
//     debugPrint('Failed to log API error: $logError');
//   }
// }

  Future<ApiResponse> _handleRequestError(DioError e) async {
    try {
      final isNetworkTimeout = e.type == DioErrorType.connectTimeout ||
          e.type == DioErrorType.receiveTimeout ||
          e.type == DioErrorType.sendTimeout;

      // Avoid recursive logging calls while the network itself is failing.
      if (!isNetworkTimeout &&
          !e.requestOptions.path.contains(ApiEndpoint.logging)) {
        await pushLog('Error in ${e.requestOptions.path}: ${e.message}');
      }

      if (e.type == DioErrorType.connectTimeout ||
          e.type == DioErrorType.other) {
        final baseUrl = dio.options.baseUrl;
        if (baseUrl.contains('10.0.2.2')) {
          return ApiResponse(
            success: false,
            status: 'error',
            error:
                'Khong ket noi duoc den server. 10.0.2.2 chi dung cho Android emulator; neu dung may that hay dat API_BASE_URL ve IP LAN cua may chay backend (vi du http://192.168.x.x:8000).',
          );
        }
        return ApiResponse(
          success: false,
          status: 'error',
          error: Strings.localized.networkErrorMessage,
        );
      }
      if (e.response == null || e.response?.data == null) {
        return ApiResponse(
          success: false,
          status: 'error',
          error: Strings.localized.somethingWentWrong,
        );
      }
      final decode = json.decode(e.response?.data);
      if (decode is Map<String?, dynamic>) {
        return ApiResponse.fromJson(decode);
      }

      return ApiResponse(
        success: false,
        status: 'error',
        error: Strings.localized.somethingWentWrong,
      );
    } catch (e) {
      return ApiResponse(
        success: false,
        status: 'error',
        error: Strings.localized.somethingWentWrong,
      );
    }
  }
}
