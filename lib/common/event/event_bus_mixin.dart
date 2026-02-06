import 'dart:async';

import 'package:event_bus/event_bus.dart';

EventBus eventBus = EventBus();

mixin EventBusMixin {
  StreamSubscription<T> listenEvent<T>(void Function(T) subscription) =>
      eventBus.on<T>().listen(subscription);

  void shareEvent<S>(S event) => eventBus.fire(event);

  static void shareStaticEvent<S>(S event) => eventBus.fire(event);

  static StreamSubscription<T> staticListenEvent<T>(void Function(T) subscription) =>
      eventBus.on<T>().listen(subscription);
}
