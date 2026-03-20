// ignore_for_file: always_specify_types
// ignore: avoid_classes_with_only_static_members
class ApiEndpoint {
  static const String login = '/api/v1/auth/login';
  static const String logout = '/api/v1/auth/logout';
  static const String me = '/api/v1/auth/me';
  static const String students = '/api/student/get_all_students';
  static const String student = '/student';
  static const String syncCheckInOutData =
      '/api/attendance/history/sync_bulk_io';
  static const String logging = "/api/log/error";
  static const String registerStudent = "/api/student/create";
  static const String pushFaceData = "/api/student/update/embedding";
  static const String pullFaceData = "/api/student/export/json";
  static const String registerStudentBatch = "/api/student/create/batch";
  static const String uploadStudentAvatar = "/api/student/avatars/upload";
  static const String uploadUserAvatar = "/auth/avatar";
  static const String registerUser = "/api/v1/auth/register";
}
