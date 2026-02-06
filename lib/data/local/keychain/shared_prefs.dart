import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';

Type typeOf<T>() => T;

@lazySingleton
class SharedPrefs {
  SharedPrefs(this.sharedPreferences);

  final SharedPreferences sharedPreferences;

  T? get<T>(String key) {
    if (typeOf<String>() == T) {
      return sharedPreferences.getString(key) as T?;
    } else if (typeOf<int>() == T) {
      return sharedPreferences.getInt(key) as T?;
    } else if (typeOf<double>() == T) {
      return sharedPreferences.getDouble(key) as T?;
    } else if (typeOf<bool>() == T) {
      return sharedPreferences.getBool(key) as T?;
    } else if (typeOf<List<String>>() == T) {
      return sharedPreferences.getStringList(key) as T?;
    } else {
      return sharedPreferences.get(key) as T?;
    }
  }

  Future<void> put<T>(String key, T? value) async {
    if (value == null) {
      await sharedPreferences.remove(key);
    } else if (typeOf<String>() == T || typeOf<String?>() == T) {
      await sharedPreferences.setString(key, value as String);
    } else if (typeOf<int>() == T || typeOf<int?>() == T) {
      await sharedPreferences.setInt(key, value as int);
    } else if (typeOf<double>() == T || typeOf<double?>() == T) {
      await sharedPreferences.setDouble(key, value as double);
    } else if (typeOf<bool>() == T || typeOf<bool?>() == T) {
      await sharedPreferences.setBool(key, value as bool);
    } else if (typeOf<List<String>>() == T || typeOf<List<String>?>() == T) {
      await sharedPreferences.setStringList(key, value as List<String>);
    } else {
      throw const FormatException('Invalid format type');
    }
  }

  Future<void> clear() async {
    await sharedPreferences.clear();
  }

  Future<void> clearKey(String key) async {
    sharedPreferences.remove(key);
  }
}
