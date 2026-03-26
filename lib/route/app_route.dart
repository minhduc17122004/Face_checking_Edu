import 'package:face_time_keeping/pages/attendance_checkin/attendance_checkin_page.dart';
import 'package:face_time_keeping/pages/checking/checking_page.dart';
import 'package:face_time_keeping/pages/course/course_detail_page.dart';
import 'package:face_time_keeping/pages/course/course_form_page.dart';
import 'package:face_time_keeping/pages/course/course_list_page.dart';
import 'package:face_time_keeping/pages/department/department_detail_page.dart';
import 'package:face_time_keeping/pages/department/department_form_page.dart';
import 'package:face_time_keeping/pages/department/department_list_page.dart';
import 'package:face_time_keeping/pages/setting/device_permission_page.dart';
import 'package:face_time_keeping/pages/setting/device_request_submit_page.dart';
import 'package:face_time_keeping/pages/domain/choose_db.dart';
import 'package:face_time_keeping/pages/domain/domain_page.dart';
import 'package:face_time_keeping/pages/room/room_form_page.dart';
import 'package:face_time_keeping/pages/room/room_list_page.dart';
import 'package:face_time_keeping/pages/room/room_selection_page.dart';
import 'package:face_time_keeping/pages/schedule/schedule_page.dart';
import 'package:face_time_keeping/pages/home/session_management/session_management_page.dart';
import 'package:face_time_keeping/pages/student/student_page.dart';
import 'package:face_time_keeping/pages/login/login_confirm_widget.dart';
import 'package:face_time_keeping/pages/login/login_page.dart';
import 'package:face_time_keeping/pages/register_face/register_face_page.dart';
import 'package:face_time_keeping/pages/setting/attendance_report.dart';
import 'package:face_time_keeping/pages/setting/setting_page.dart';
import 'package:face_time_keeping/pages/setting/server_setting_page.dart';
import 'package:face_time_keeping/pages/student_group/student_group_form_page.dart';
import 'package:face_time_keeping/pages/student_group/student_group_list_page.dart';
import 'package:face_time_keeping/pages/account/profile_page.dart';
import 'package:face_time_keeping/pages/setting/teacher_list_page.dart';
import 'package:face_time_keeping/pages/teacher/teacher_assignment_page.dart';
import 'package:face_time_keeping/pages/setting/user_register_page.dart';
import 'package:face_time_keeping/pages/setting/time_slot_page.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../pages/bootstrap/bootstrap_page.dart';
import '../pages/tab/tab.dart';

// ignore_for_file: avoid_classes_with_only_static_members
class RouterName {
  static const String boostrap = '/';
  static const String home = '/home';
  static const String login = '/login';
  static const String checking = '/checking';
  static const String students = '/students';
  static const String registerFace = '/registerFace';
  static const String adminConfirm = '/adminConfirm';
  static const String domain = '/domain';
  static const String settings = '/settings';
  static const String attendanceReport = '/attendanceReport';
  static const String chooseDb = '/chooseDb';
  static const String serverSettings = '/serverSettings';
  static const String studentGroupList = '/studentGroupList';
  static const String studentGroupForm = '/studentGroupForm';
  static const String courseList = '/courseList';
  static const String profile = '/profile';
  static const String teacherList = '/teacherList';
  static const String userRegister = '/userRegister';

  // Phase 9/10 Routes
  static const String departmentList = '/departments';
  static const String departmentForm = '/departments/form';
  static const String departmentDetail = '/departments/detail';
  static const String roomList = '/rooms';
  static const String roomForm = '/rooms/form';
  static const String roomSessions = '/rooms/sessions';
  static const String roomSelection = '/rooms/selection';
  static const String sessionManagement = '/session-management';
  static const String courseForm = '/courses/form';
  static const String courseDetail = '/courses/detail';
  static const String schedule = '/schedule';
  static const String teacherAssignment = '/teachers/assignment';
  static const String timeSlot = '/settings/time-slots';
  static const String devicePermission = '/settings/device-permission';
  static const String deviceRequestSubmit = '/settings/device-request-submit';
  static const String attendanceCheckin = '/attendance-checkin';
}

class AppRoutes {
  static Route<dynamic>? onGenerateRoutes(RouteSettings settings) {
    if (kDebugMode) {
      print('Navigate to:${settings.name ?? ''}');
    }
    switch (settings.name) {
      case RouterName.boostrap:
        return _materialRoute(settings, const BootstrapPage());
      case RouterName.home:
        return _materialRoute(settings, const TabPage());
      case RouterName.domain:
        return _materialRoute(settings, const DomainPage());
      case RouterName.login:
        return _materialRoute(settings, const LoginPage());
      case RouterName.adminConfirm:
        return _materialRoute(settings, const LoginConfirmWidget());
      case RouterName.checking:
        return _materialRoute(settings, const CheckingPage());
      case RouterName.students:
        return _materialRoute(settings, const StudentPage());
      case RouterName.registerFace:
        return _materialRoute(settings, const RegisterFacePage());
      case RouterName.settings:
        return _materialRoute(settings, const SettingPage());
      case RouterName.serverSettings:
        return _materialRoute(settings, const ServerSettingPage());
      case RouterName.attendanceReport:
        return _materialRoute(settings, const AttendanceReport());
      case RouterName.studentGroupList:
        return _materialRoute(settings, const StudentGroupListPage());
      case RouterName.studentGroupForm:
        return _materialRoute(
          settings,
          StudentGroupFormPage(studentGroup: settings.arguments as dynamic),
        );
      case RouterName.courseList:
        return _materialRoute(settings, const CourseListPage());
      case RouterName.chooseDb:
        return _materialRoute(
            settings, ChooseDb(dbList: settings.arguments as List<String>));
      case RouterName.profile:
        return _materialRoute(settings, const ProfilePage());
      case RouterName.teacherList:
        return _materialRoute(settings, const TeacherListPage());
      case RouterName.userRegister:
        return _materialRoute(settings, const UserRegisterPage());

      // Phase 9/10 Routes
      case RouterName.departmentList:
        return _materialRoute(settings, const DepartmentListPage());
      case RouterName.departmentForm:
        return _materialRoute(
          settings,
          DepartmentFormPage(department: settings.arguments as dynamic),
        );
      case RouterName.departmentDetail:
        return _materialRoute(
          settings,
          DepartmentDetailPage(department: settings.arguments as dynamic),
        );
      case RouterName.roomList:
        return _materialRoute(settings, const RoomListPage());
      case RouterName.roomForm:
        return _materialRoute(
          settings,
          RoomFormPage(room: settings.arguments as dynamic),
        );
      case RouterName.roomSelection:
        return _materialRoute(settings, const RoomSelectionPage());
      case RouterName.sessionManagement:
        return _materialRoute(settings, const SessionManagementPage());
      case RouterName.courseForm:
        return _materialRoute(
          settings,
          CourseFormPage(course: settings.arguments as dynamic),
        );
      case RouterName.courseDetail:
        return _materialRoute(
          settings,
          CourseDetailPage(course: settings.arguments as dynamic),
        );
      case RouterName.schedule:
        return _materialRoute(
          settings,
          SchedulePage(courseId: settings.arguments as String?),
        );
      case RouterName.teacherAssignment:
        return _materialRoute(settings, const TeacherAssignmentPage());
      case RouterName.timeSlot:
        return _materialRoute(settings, const TimeSlotPage());
      case RouterName.devicePermission:
        return _materialRoute(settings, const DevicePermissionPage());
      case RouterName.deviceRequestSubmit:
        return _materialRoute(settings, const DeviceRequestSubmitPage());
      case RouterName.attendanceCheckin:
        return _materialRoute(
          settings,
          AttendanceCheckinPage(
            args: settings.arguments as AttendanceCheckinArgs,
          ),
        );
    }
    return null;
  }

  static Route<dynamic> _materialRoute(RouteSettings settings, Widget view) {
    return MaterialPageRoute<dynamic>(
      settings: settings,
      builder: (_) => view,
    );
  }

  // ignore: unused_element
  static Route<dynamic> _pageRouteBuilderWithPresentEffect(
      RouteSettings settings, Widget view) {
    return PageRouteBuilder<dynamic>(
      settings: settings,
      pageBuilder: (BuildContext context, Animation<double> animation,
              Animation<double> secondaryAnimation) =>
          view,
      transitionsBuilder: (BuildContext context, Animation<double> animation,
          Animation<double> secondaryAnimation, Widget child) {
        const Offset begin = Offset(0.0, 1.0);
        const Offset end = Offset.zero;
        const Cubic curve = Curves.ease;

        final Animatable<Offset> tween = Tween<Offset>(begin: begin, end: end)
            .chain(CurveTween(curve: curve));

        return SlideTransition(
          position: animation.drive(tween),
          child: child,
        );
      },
    );
  }

  // ignore: unused_element
  static Route<dynamic> _pageRouteBuilderWithFadeEffect(
      RouteSettings settings, Widget view) {
    return PageRouteBuilder<dynamic>(
      settings: settings,
      opaque: false,
      pageBuilder: (BuildContext context, Animation<double> animation,
              Animation<double> secondaryAnimation) =>
          view,
      transitionsBuilder: (BuildContext context, Animation<double> animation,
          Animation<double> secondaryAnimation, Widget child) {
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      },
    );
  }
}
