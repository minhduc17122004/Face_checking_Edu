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
    String _baseUrl = '';
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
    _baseUrl = url;
  }
}
