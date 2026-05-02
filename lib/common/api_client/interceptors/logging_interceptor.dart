

import 'package:dio/dio.dart';

class LoggingInterceptor extends Interceptor {

  LoggingInterceptor();
    @override
    void onError(DioError err, ErrorInterceptorHandler handler) async {
      // EventBusMixin.shareStaticEvent(LoggingEvent(apiInfo: ApiInfo(
      //     response: LoggingApiResponse(
      //       status_code: err.response?.statusCode ?? 0,
      //       message: err.message,
      //       error_code: err.response?.statusCode ?? 0,
      //     ),
      //   )));
    }
}