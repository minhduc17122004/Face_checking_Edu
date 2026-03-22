// ignore_for_file: always_specify_types
// ignore: avoid_classes_with_only_static_members
class ApiEndpoint {
  static const String login = '/api/v1/auth/login';
  static const String logout = '/api/v1/auth/logout';
  static const String refreshToken = '/api/v1/auth/refresh';
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
  static const String uploadUserAvatar = "/api/v1/auth/avatar";
  static const String registerUser = "/api/v1/auth/register";
  static const String getUsersByRole = "/api/v1/users/";

  // --- V1 Endpoints (Phase 8 & 9) ---

  // Departments
  static const String departments = "/api/v1/departments";

  // Rooms
  static const String rooms = "/api/v1/rooms";
  static const String roomCourses = "/api/v1/rooms/{id}/courses";

  // Courses
  static const String courses = "/api/v1/courses";
  static const String courseStudents = "/api/v1/courses/{id}/students";
  static const String courseAssignRoom = "/api/v1/courses/{id}/assign-room";

  // TimeSlots
  static const String timeSlots = "/api/v1/time-slots";

  // Schedules
  static const String schedules = "/api/v1/schedules";

  // Sessions
  static const String sessions = "/api/v1/sessions";
  static const String sessionActivate = "/api/v1/sessions/{id}/activate";
  static const String sessionClose = "/api/v1/sessions/{id}/close";
  static const String sessionSummary = "/api/v1/sessions/{id}/summary";
  static const String sessionGenerateDaily = "/api/v1/sessions/generate-daily";

  // Teachers
  static const String teachers = "/api/v1/teachers";
  static const String teacherAssignDepartment = "/api/v1/teachers/{id}/assign-department";

  // Devices
  static const String devices = "/api/v1/devices";
  static const String deviceSync = "/api/v1/devices/{id}/sync";
  static const String deviceAssignRoom = "/api/v1/devices/{id}/assign-room";
  static const String deviceBulkAttendance = "/api/v1/devices/bulk-attendance";

  // Metrics
  static const String metrics = "/api/v1/metrics";
}