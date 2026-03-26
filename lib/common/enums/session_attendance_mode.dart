import 'package:collection/collection.dart';

enum SessionAttendanceMode { preset, flexible, custom }

extension SessionAttendanceModeX on SessionAttendanceMode {
  String get value {
    switch (this) {
      case SessionAttendanceMode.preset:
        return 'preset';
      case SessionAttendanceMode.flexible:
        return 'flexible';
      case SessionAttendanceMode.custom:
        return 'custom';
    }
  }

  String get label {
    switch (this) {
      case SessionAttendanceMode.preset:
        return 'Cố định';
      case SessionAttendanceMode.flexible:
        return 'Linh hoạt';
      case SessionAttendanceMode.custom:
        return 'Tự thiết lập';
    }
  }

  String get shortLabel => label;

  static SessionAttendanceMode? fromString(String? value) {
    if (value == null) return null;
    return SessionAttendanceMode.values.firstWhereOrNull(
      (e) => e.name.toUpperCase() == value.toUpperCase(),
    );
  }
}
