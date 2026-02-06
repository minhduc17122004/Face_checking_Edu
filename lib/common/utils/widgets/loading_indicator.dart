import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

import '../../resources/index.dart';

class IgnoreLoadingIndicator {
  factory IgnoreLoadingIndicator() {
    return _dialog;
  }

  IgnoreLoadingIndicator._internal();

  static final IgnoreLoadingIndicator _dialog = IgnoreLoadingIndicator._internal();

  final GlobalKey<State> _key = GlobalKey<State>();

  bool isShowing = false;
  Timer? _timer;
  BuildContext? _currentContext;
  final int _timeout = 20;

  Future<void> show(BuildContext context) async {
    if (isShowing) {
      return;
    }
    _currentContext = context;
    _startTimer();
    isShowing = true;
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return WillPopScope(
          key: _key,
          onWillPop: () async {
            _stopTimer();
            return true;
          },
          child: const Center(
            child: SpinKitCircle(
              color: AppColors.primaryColor,
              size: 70,
            ),
          ),
        );
      },
    );
  }

  void hide(BuildContext context) {
    if (!isShowing) {
      return;
    }
    isShowing = false;
    _stopTimer();
    Navigator.of(context, rootNavigator: true).pop();
  }

  void _startTimer() {
    _timer = Timer.periodic(Duration(seconds: _timeout), (timer) {
      if (_currentContext != null) {
        hide(_currentContext!);
      }
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }
}
