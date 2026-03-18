// ignore_for_file: always_specify_types
// ignore: avoid_classes_with_only_static_members
class ApiEndpoint {
  static const String login = '/auth/login';
  static const String logout = '/auth/logout';
  static const String me = '/auth/me';
  static const String employees = '/api/employee/get_all_employees';
  static const String employee = '/employee';
  static const String syncCheckInOutData =
      '/api/attendance/history/sync_bulk_io';
  static const String logging = "/api/log/error";
  static const String registerEmployee = "/api/employee/create";
  static const String pushFaceData = "/api/employee/update/embedding";
  static const String pullFaceData = "/api/employee/export/json";
  static const String registerEmployeeBatch = "/api/employee/create/batch";
  static const String uploadEmployeeAvatar = "/api/employee/avatars/upload";
  static const String uploadUserAvatar = "/auth/avatar";
}
