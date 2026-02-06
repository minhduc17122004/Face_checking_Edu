

import 'package:dio/dio.dart';

import 'package:face_time_keeping/common/event/event_bus_event.dart';
import 'package:face_time_keeping/common/event/event_bus_mixin.dart';
import 'package:face_time_keeping/data/models/logging_model.dart';


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