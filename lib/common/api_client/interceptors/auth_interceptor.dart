import 'package:dio/dio.dart';
import 'package:face_time_keeping/route/navigator.dart';

import '../../../data/local/keychain/shared_prefs.dart';
import '../../../data/local/keychain/shared_prefs_key.dart';
import '../../../data/remote/api_endpoint.dart';
import '../../../di/injection.dart';
import '../../../route/app_route.dart';
import '../../event/event_bus_event.dart';
import '../../event/event_bus_mixin.dart';

class AuthInterceptor extends Interceptor with EventBusMixin {
  final SharedPrefs _sharedPrefs = getIt<SharedPrefs>();

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final String? token = _sharedPrefs.get(SharedPrefsKey.token);
    if (token != null && !options.path.contains(ApiEndpoint.login)) {
      options.headers['api-key'] = token;
    }
    super.onRequest(options, handler);
  }

  @override
  void onError(DioError err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode == 401) {
      shareEvent(LogoutEvent());
      AppNavigator.pushNamedAndRemoveUntil(RouterName.login, (r) => false);
    }
    super.onError(err, handler);
  }
}
