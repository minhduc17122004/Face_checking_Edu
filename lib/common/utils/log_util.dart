import 'package:face_time_keeping/data/local/local_service.dart';
import 'package:face_time_keeping/data/models/logging_model.dart';
import 'package:face_time_keeping/data/remote/logging_service.dart';
import 'package:face_time_keeping/di/injection.dart';
import 'package:flutter_liveness_detection_randomized_plugin/index.dart';

Future<void> pushLog(String message) async {
  try {
    final loggingService = getIt<LoggingService>();
    final localService = getIt<LocalService>();
    final url = localService.getServerUrl();
    debugPrint('pushLog: $message');
    if (url.trim().isEmpty) {
      debugPrint('pushLog skipped: empty domain');
      return;
    }
    await loggingService.log(
        ApiInfo(
          response: LoggingApiResponse(
            message: message,
          ),
        ),
        url: url);
  } catch (e) {
    debugPrint('Error pushing log: $e');
  }
}
