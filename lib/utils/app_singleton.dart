import '../di/injection.dart';
import '../entities/user.dart';
import '../data/local/keychain/shared_prefs.dart';
import '../data/local/keychain/shared_prefs_key.dart';

class AppSingleton {
  factory AppSingleton() {
    return _singleton;
  }

  AppSingleton._internal();

  static AppSingleton get instance => AppSingleton();

  static final AppSingleton _singleton = AppSingleton._internal();

  final SharedPrefs _sharedPrefs = getIt<SharedPrefs>();

  User? user;

  String? get accessToken => _sharedPrefs.get(SharedPrefsKey.token);
}
