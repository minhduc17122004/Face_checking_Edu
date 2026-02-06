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
  ApiClient({required this.dio}) {
    late final cookieJar;
    final BuildConfig buildConfig = getIt<BuildConfig>();
    dio.options.baseUrl = buildConfig.kBaseUrl;
    cookieJar = CookieJar();
    dio.interceptors.add(AuthInterceptor());
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

  void updateConfigBaseUrl(String url) {
    dio.options.baseUrl = url;
  }

  Future<ApiResponse> post(
      {required String path,
      dynamic data,
      Map<String, dynamic>? headers,
      ProgressCallback? onSendProgress,
      CancelToken? cancelToken}) async {
    dio.options.headers.addAll(headers ?? _defaultHeaders);

    return responseWrapper(dio.post<dynamic>(path,
        data: data, onSendProgress: onSendProgress, cancelToken: cancelToken));
  }

  Future<ApiResponse> put({
    required String path,
    dynamic data,
    Map<String, dynamic>? headers,
  }) async {
    dio.options.headers.addAll(headers ?? {});
    return responseWrapper(dio.put<dynamic>(path, data: data));
  }

  Future<ApiResponse> patch({required String path, dynamic data}) async {
    return responseWrapper(dio.patch<dynamic>(path, data: data));
  }

  Future<ApiResponse> delete({required String path, dynamic data}) async {
    return responseWrapper(dio.delete<dynamic>(path, data: data));
  }

  Future<ApiResponse> get({
    required String path,
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
  }) async {
    dio.options.headers.addAll(headers ?? {});
    return responseWrapper(dio.request<dynamic>(
      path,
      queryParameters: queryParameters,
      options: Options(
        method: "GET",
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
        },
      ),
      data: data,
    ));
  }

  Future<ApiResponse> download(
      {required String path,
      required String savePath,
      ProgressCallback? onReceiveProgress}) async {
    try {
      await dio.download(path, savePath, onReceiveProgress: onReceiveProgress);
      return ApiResponse(success: true);
    } on DioError catch (e) {
      return _handleRequestError(e);
    }
  }

  Future<ApiResponse> responseWrapper(Future<Response<dynamic>> func) async {
    try {
      final Response<dynamic> response = await func;
      Map<String?, dynamic>? decode;

      decode = (response.data is Map<String, dynamic>)
          ? response.data
          : json.decode(response.data);
      if (decode is Map<String?, dynamic>) {
        return ApiResponse.fromJson(decode);
      }
      return ApiResponse(
        success: false,
        status: 'error',
        error: Strings.localized.somethingWentWrong,
      );
    } on DioError catch (e) {
      debugPrint('error: $e');
      final response = e.response?.data;
      if (response is Map<String, dynamic>) {
        return ApiResponse(
          success: false,
          status: 'error',
          error: response['error'] ?? Strings.localized.somethingWentWrong,
        );
      }
      return await _handleRequestError(e);
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
      if (!e.requestOptions.path.contains(ApiEndpoint.logging)) {
        await pushLog('Error in ${e.requestOptions.path}: ${e.message}');
      }
      if (e.type == DioErrorType.connectTimeout ||
          e.type == DioErrorType.other) {
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
