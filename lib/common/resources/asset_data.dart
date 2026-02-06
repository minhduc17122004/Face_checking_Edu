import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

class AssetData {
  static const String currencies = 'assets/data/currencies.json';
}

extension AssetDataX on String {
  Future<dynamic> getJson({bool cache = true}) async {
    final String snapShot = await rootBundle.loadString(this, cache: cache);
    return jsonDecode(snapShot);
  }
}
