import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class KeyboardController {
  final FocusNode _focusNode = FocusNode();
  final _keyEventStreamController = StreamController<RawKeyEvent>();

  Stream<RawKeyEvent> get keyEvents => _keyEventStreamController.stream;
  FocusNode get focusNode => _focusNode;

  KeyboardController() {
    RawKeyboard.instance.addListener(_onKeyEvent);
  }

  void _onKeyEvent(RawKeyEvent event) {
    _keyEventStreamController.add(event);
  }

  void dispose() {
    RawKeyboard.instance.removeListener(_onKeyEvent);
    _keyEventStreamController.close();
    _focusNode.dispose();
  }
}
