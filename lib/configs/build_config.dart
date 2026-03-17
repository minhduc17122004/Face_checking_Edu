import 'package:injectable/injectable.dart';

abstract class BuildConfig {
  bool get debugLog;

  String get kBaseUrl;

  String get kBaseImageUrl;

  String get kDefaultAppName;

  String get kAppStoreUrl;

  String get kPlayStoreUrl;

  String get kakaoApiKey;


  void setBaseUrl(String url);
  
}

@LazySingleton(as: BuildConfig, env: [Environment.prod])
class BuildConfigProd implements BuildConfig {
  String _baseUrl = _normalizeBaseUrl(
    const String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'http://192.168.1.167:8000',
    ),
  );

  static String _normalizeBaseUrl(String url) {
    final trimmed = url.trim();
    if (trimmed.endsWith('/')) {
      return trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }

  @override
  String get kBaseUrl => _baseUrl;
  @override
  bool debugLog = true;

  @override
  String kBaseImageUrl = '';
  @override
  String kDefaultAppName = '';

  @override
  String kAppStoreUrl = '';

  @override
  String kPlayStoreUrl = '';

  @override
  String kakaoApiKey = '';
  @override
  void setBaseUrl(String url) {
    _baseUrl = _normalizeBaseUrl(url);
  }
}
