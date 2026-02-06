import 'package:collection/collection.dart';

enum BluetoothStatus { unknown, unavailable, unauthorized, turningOn, on, turningOff, off }
extension BluetoothStatusX on BluetoothStatus {
  static BluetoothStatus? initFrom(String? value) {
    return BluetoothStatus.values.firstWhereOrNull((BluetoothStatus e) => e.name == value);
  }
}