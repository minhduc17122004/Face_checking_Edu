import 'package:flutter/material.dart';

extension BuildContextX on BuildContext {
  bool isLandscape() {
    final Orientation orientation = MediaQuery.of(this).orientation;
    return orientation == Orientation.landscape;
  }

  T? getRouteArguments<T>() {
    if (ModalRoute.of(this)?.settings.arguments is! T) {
      return null;
    }
    final Object? arguments = ModalRoute.of(this)?.settings.arguments;
    return arguments != null ? ModalRoute.of(this)?.settings.arguments as T? : null;
  }
}
