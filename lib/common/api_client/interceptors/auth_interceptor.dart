import 'package:dio/dio.dart';
import 'package:face_time_keeping/route/navigator.dart';
import 'package:flutter/widgets.dart';

import '../../../data/local/keychain/shared_prefs.dart';
import '../../../data/local/keychain/shared_prefs_key.dart';
import '../../../data/remote/api_endpoint.dart';
import '../../../di/injection.dart';
import '../../../route/app_route.dart';
import '../../event/event_bus_event.dart';
import '../../event/event_bus_mixin.dart';

class AuthInterceptor extends Interceptor with EventBusMixin {
  final SharedPrefs _sharedPrefs = getIt<SharedPrefs>();
  static bool _isHandlingUnauthorized = false;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final String? token = _sharedPrefs.get(SharedPrefsKey.token);
    if (token != null && !options.path.contains(ApiEndpoint.login)) {
      options.headers['Authorization'] = 'Bearer $token';
      options.headers['api-key'] = token; // Fallback cho các API cũ nếu còn gọi
    }
    super.onRequest(options, handler);
  }

  @override
  void onError(DioError err, ErrorInterceptorHandler handler) {
    final path = err.requestOptions.path;
    final hasToken =
        (_sharedPrefs.get(SharedPrefsKey.token) ?? '').trim().isNotEmpty;
    final isUnauthorized = err.response?.statusCode == 401;
    final isAuthRequest =
        path.contains(ApiEndpoint.login) || path.contains(ApiEndpoint.logout);

    // Do not force logout/navigation for failed login attempts.
    if (isUnauthorized &&
        hasToken &&
        !isAuthRequest &&
        !_isHandlingUnauthorized) {
      _isHandlingUnauthorized = true;
      shareEvent(LogoutEvent());

      WidgetsBinding.instance.addPostFrameCallback((_) {
        AppNavigator.pushNamedAndRemoveUntil(RouterName.login, (r) => false);
        _isHandlingUnauthorized = false;
      });
    }
    super.onError(err, handler);
  }
}
