import 'dart:async';
import 'dart:io';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:face_time_keeping/data/local/keychain/shared_prefs.dart';
import 'package:face_time_keeping/data/local/keychain/shared_prefs_key.dart';
import 'package:face_time_keeping/data/remote/api_endpoint.dart';
import 'package:face_time_keeping/di/injection.dart';

class CookieInterceptor extends Interceptor {
  final CookieJar cookieJar;
  final SharedPrefs _sharedPrefs = getIt<SharedPrefs>();

  CookieInterceptor(this.cookieJar);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    cookieJar.loadForRequest(options.uri).then((cookies) {
      var cookie = getCookies(cookies);
      if (cookie.isNotEmpty) {
        options.headers["Cookie"] = cookie;
      }
      handler.next(options);
    }).catchError((e, stackTrace) {
      var err = DioError(requestOptions: options, error: e);
      err.stackTrace = stackTrace;
      handler.reject(err, true);
    });
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    _saveCookies(response)
        .then((_) => handler.next(response))
        .catchError((e, stackTrace) {
      var err = DioError(requestOptions: response.requestOptions, error: e);
      err.stackTrace = stackTrace;
      handler.reject(err, true);
    });
  }

  @override
  void onError(DioError err, ErrorInterceptorHandler handler) {
    if (err.response != null) {
      _saveCookies(err.response!)
          .then((_) => handler.next(err))
          .catchError((e, stackTrace) {
        var _err = DioError(
          requestOptions: err.response!.requestOptions,
          error: e,
        );
        _err.stackTrace = stackTrace;
        handler.next(_err);
      });
    } else {
      handler.next(err);
    }
  }

  Future<void> _saveCookies(Response response) async {
    final cookies = response.headers[HttpHeaders.setCookieHeader];
    if (cookies != null) {
      final cookieList =
          cookies.map((str) => Cookie.fromSetCookieValue(str)).toList();

      // Specifically find the session_id cookie
      final sessionCookie = cookieList.firstWhere((c) => c.name == 'session_id',
          orElse: () => Cookie('', ''));

      if (sessionCookie.value.isNotEmpty &&
          response.requestOptions.path.contains(ApiEndpoint.login)) {
        // Save ONLY the value or the formatted string 'session_id=VALUE'
        await _sharedPrefs.put(
            SharedPrefsKey.savedCookied, sessionCookie.value);
      }

      await cookieJar.saveFromResponse(response.requestOptions.uri, cookieList);
    }
  }

  static String getCookies(List<Cookie> cookies) {
    if (cookies.isNotEmpty) {
      return cookies.first.toString();
    }
    return '';
  }
}
