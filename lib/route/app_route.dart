import 'package:face_time_keeping/pages/checking/checking_page.dart';
import 'package:face_time_keeping/pages/domain/choose_db.dart';
import 'package:face_time_keeping/pages/domain/domain_page.dart';
import 'package:face_time_keeping/pages/employee/employee_page.dart';
import 'package:face_time_keeping/pages/login/login_confirm_widget.dart';
import 'package:face_time_keeping/pages/login/login_page.dart';
import 'package:face_time_keeping/pages/register_face/register_face_page.dart';
import 'package:face_time_keeping/pages/setting/attendance_report.dart';
import 'package:face_time_keeping/pages/setting/setting_page.dart';
import 'package:face_time_keeping/pages/setting/server_setting_page.dart';

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
  static const String employees = '/employees';
  static const String registerFace = '/registerFace';
  static const String adminConfirm = '/adminConfirm';
  static const String domain = '/domain';
  static const String settings = '/settings';
  static const String attendanceReport = '/attendanceReport';
  static const String chooseDb = '/chooseDb';
  static const String serverSettings = '/serverSettings';
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
      case RouterName.employees:
        return _materialRoute(settings, const EmployeePage());
      case RouterName.registerFace:
        return _materialRoute(settings, const RegisterFacePage());
      case RouterName.settings:
        return _materialRoute(settings, const SettingPage());
      case RouterName.serverSettings:
        return _materialRoute(settings, const ServerSettingPage());
      case RouterName.attendanceReport:
        return _materialRoute(settings, const AttendanceReport());
      case RouterName.chooseDb:
        return _materialRoute(
            settings, ChooseDb(dbList: settings.arguments as List<String>));
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
