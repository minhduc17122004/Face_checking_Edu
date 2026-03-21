import 'package:dio/dio.dart';
import 'package:face_time_keeping/route/navigator.dart';
import 'package:flutter/widgets.dart';
import 'package:injectable/injectable.dart';

import '../../../data/local/keychain/shared_prefs.dart';
import '../../../data/local/keychain/shared_prefs_key.dart';
import '../../../data/remote/api_endpoint.dart';
import '../../../route/app_route.dart';
import '../../event/event_bus_event.dart';
import '../../event/event_bus_mixin.dart';

@lazySingleton
class AuthInterceptor extends QueuedInterceptor with EventBusMixin {
  AuthInterceptor(this._sharedPrefs);

  final SharedPrefs _sharedPrefs;
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
  Future<void> onError(DioError err, ErrorInterceptorHandler handler) async {
    final path = err.requestOptions.path;
    final hasToken =
        (_sharedPrefs.get(SharedPrefsKey.token) ?? '').trim().isNotEmpty;
    final isUnauthorized = err.response?.statusCode == 401;
    final isAuthRequest =
        path.contains(ApiEndpoint.login) || 
        path.contains(ApiEndpoint.logout) ||
        path.contains(ApiEndpoint.refreshToken);

    if (isUnauthorized && hasToken && !isAuthRequest) {
      if (!_isHandlingUnauthorized) {
        _isHandlingUnauthorized = true;
        
        final refreshToken = _sharedPrefs.get(SharedPrefsKey.refreshToken) ?? '';
        if (refreshToken.isNotEmpty) {
          try {
            // Call refresh API với 1 instance Dio độc lập (không đi qua interceptor này)
            final dio = Dio(BaseOptions(baseUrl: err.requestOptions.baseUrl));
            final refreshResponse = await dio.post(
              ApiEndpoint.refreshToken,
              data: {'refresh_token': refreshToken},
            );

            if (refreshResponse.statusCode == 200 || refreshResponse.statusCode == 201) {
              final newAccessToken = refreshResponse.data['access_token'];
              final newRefreshToken = refreshResponse.data['refresh_token'];
              
              // Lưu session mới
              await _sharedPrefs.put(SharedPrefsKey.token, newAccessToken);
              await _sharedPrefs.put(SharedPrefsKey.refreshToken, newRefreshToken);
              
              _isHandlingUnauthorized = false;
              
              // Cập nhật token cho request gốc và thử lại (Retry)
              err.requestOptions.headers['Authorization'] = 'Bearer $newAccessToken';
              err.requestOptions.headers['api-key'] = newAccessToken;
              
              try {
                final retryResponse = await dio.fetch(err.requestOptions);
                return handler.resolve(retryResponse);
              } catch (e) {
                // Retry failed
              }
            }
          } catch (e) {
            // Lỗi refresh token
          }
        }
        
        // Refresh thất bại => Logout
        _isHandlingUnauthorized = false;
        _forceLogout();
        return handler.next(err);
      } else {
        // Đang refresh -> có thể reject các request tiếp theo bằng chính lỗi cũ, 
        // QueuedInterceptor sẽ giúp các request khác đợi, lúc này token đã fetch xong (nếu Queue bật)
        // Khi sử dụng QueuedInterceptor ở trên, đoạn này hiếm khi chạy song song 
      }
    }
    
    super.onError(err, handler);
  }

  void _forceLogout() {
    _sharedPrefs.put(SharedPrefsKey.token, null);
    _sharedPrefs.put(SharedPrefsKey.refreshToken, null);
    shareEvent(LogoutEvent());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppNavigator.pushNamedAndRemoveUntil(RouterName.login, (r) => false);
    });
  }
}
