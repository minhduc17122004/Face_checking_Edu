// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// InjectableConfigGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:dio/dio.dart' as _i361;
import 'package:face_time_keeping/common/api_client/api_client.dart' as _i644;
import 'package:face_time_keeping/common/api_client/interceptors/auth_interceptor.dart'
    as _i464;
import 'package:face_time_keeping/configs/build_config.dart' as _i239;
import 'package:face_time_keeping/data/local/hive_service.dart' as _i106;
import 'package:face_time_keeping/data/local/keychain/shared_prefs.dart'
    as _i340;
import 'package:face_time_keeping/data/local/local_service.dart' as _i840;
import 'package:face_time_keeping/data/remote/attendance_checkin_service.dart'
    as _i549;
import 'package:face_time_keeping/data/remote/attendance_history_service.dart'
    as _i102;
import 'package:face_time_keeping/data/remote/authentication_service.dart'
    as _i368;
import 'package:face_time_keeping/data/remote/course_service.dart' as _i256;
import 'package:face_time_keeping/data/remote/department_service.dart' as _i276;
import 'package:face_time_keeping/data/remote/device_request_service.dart'
    as _i141;
import 'package:face_time_keeping/data/remote/device_service.dart' as _i607;
import 'package:face_time_keeping/data/remote/logging_service.dart' as _i513;
import 'package:face_time_keeping/data/remote/room_service.dart' as _i492;
import 'package:face_time_keeping/data/remote/room_session_service.dart'
    as _i1001;
import 'package:face_time_keeping/data/remote/schedule_service.dart' as _i566;
import 'package:face_time_keeping/data/remote/session_service.dart' as _i440;
import 'package:face_time_keeping/data/remote/student_group_service.dart'
    as _i691;
import 'package:face_time_keeping/data/remote/teacher_service.dart' as _i169;
import 'package:face_time_keeping/data/remote/time_slot_service.dart' as _i148;
import 'package:face_time_keeping/data/remote/user_service.dart' as _i687;
import 'package:face_time_keeping/di/modules.dart' as _i754;
import 'package:face_time_keeping/pages/account/account_cubit.dart' as _i607;
import 'package:face_time_keeping/pages/attendance_checkin/bloc/attendance_checkin_bloc.dart'
    as _i586;
import 'package:face_time_keeping/pages/bloc/app_bloc.dart' as _i578;
import 'package:face_time_keeping/pages/bootstrap/bootstrap_cubit.dart'
    as _i806;
import 'package:face_time_keeping/pages/checking/bloc/checking_bloc.dart'
    as _i309;
import 'package:face_time_keeping/pages/course/bloc/course_bloc.dart' as _i995;
import 'package:face_time_keeping/pages/department/bloc/department_bloc.dart'
    as _i858;
import 'package:face_time_keeping/pages/domain/bloc/domain_bloc.dart' as _i981;
import 'package:face_time_keeping/pages/history/bloc/attendance_history_bloc.dart'
    as _i496;
import 'package:face_time_keeping/pages/home/session_management/bloc/session_management_cubit.dart'
    as _i542;
import 'package:face_time_keeping/pages/login/bloc/login_bloc.dart' as _i128;
import 'package:face_time_keeping/pages/register_face/bloc/register_face_bloc.dart'
    as _i734;
import 'package:face_time_keeping/pages/room/bloc/room_bloc.dart' as _i257;
import 'package:face_time_keeping/pages/room/room_session/bloc/room_session_bloc.dart'
    as _i905;
import 'package:face_time_keeping/pages/schedule/bloc/schedule_bloc.dart'
    as _i836;
import 'package:face_time_keeping/pages/setting/cubit/attendance_report_cubit.dart'
    as _i664;
import 'package:face_time_keeping/pages/setting/cubit/device_permission/device_permission_cubit.dart'
    as _i762;
import 'package:face_time_keeping/pages/setting/cubit/server_setting/server_setting_cubit.dart'
    as _i447;
import 'package:face_time_keeping/pages/setting/cubit/setting/setting_cubit.dart'
    as _i775;
import 'package:face_time_keeping/pages/student/blocs/student_bloc.dart'
    as _i1029;
import 'package:face_time_keeping/pages/student_group/bloc/student_group_cubit.dart'
    as _i850;
import 'package:face_time_keeping/pages/teacher/bloc/teacher_bloc.dart'
    as _i371;
import 'package:face_time_keeping/utils/csv_util.dart' as _i1018;
import 'package:get_it/get_it.dart' as _i174;
import 'package:injectable/injectable.dart' as _i526;
import 'package:shared_preferences/shared_preferences.dart' as _i460;

const String _prod = 'prod';

extension GetItInjectableX on _i174.GetIt {
// initializes the registration of main-scope dependencies inside of GetIt
  Future<_i174.GetIt> init({
    String? environment,
    _i526.EnvironmentFilter? environmentFilter,
  }) async {
    final gh = _i526.GetItHelper(
      this,
      environment,
      environmentFilter,
    );
    final injectableModule = _$InjectableModule();
    await gh.factoryAsync<_i460.SharedPreferences>(
      () => injectableModule.prefs,
      preResolve: true,
    );
    gh.lazySingleton<_i361.Dio>(() => injectableModule.dio);
    gh.lazySingleton<_i1018.CsvUtil>(() => _i1018.CsvUtil());
    gh.lazySingleton<_i106.HiveService>(() => _i106.HiveServiceImplement());
    gh.singleton<_i578.AppBloc>(() => _i578.AppBloc(gh<_i106.HiveService>()));
    gh.lazySingleton<_i239.BuildConfig>(
      () => _i239.BuildConfigProd(),
      registerFor: {_prod},
    );
    gh.lazySingleton<_i340.SharedPrefs>(
        () => _i340.SharedPrefs(gh<_i460.SharedPreferences>()));
    gh.lazySingleton<_i464.AuthInterceptor>(
        () => _i464.AuthInterceptor(gh<_i340.SharedPrefs>()));
    gh.singleton<_i644.ApiClient>(() => _i644.ApiClient(
          dio: gh<_i361.Dio>(),
          authInterceptor: gh<_i464.AuthInterceptor>(),
        ));
    gh.lazySingleton<_i549.AttendanceCheckinService>(
        () => _i549.AttendanceCheckinServiceImplement(gh<_i644.ApiClient>()));
    gh.lazySingleton<_i256.CourseService>(
        () => _i256.CourseServiceImplement(gh<_i644.ApiClient>()));
    gh.lazySingleton<_i840.LocalService>(() => _i840.LocalServiceImplement(
          gh<_i340.SharedPrefs>(),
          gh<_i644.ApiClient>(),
          gh<_i106.HiveService>(),
          gh<_i1018.CsvUtil>(),
        ));
    gh.factory<_i586.AttendanceCheckinBloc>(() =>
        _i586.AttendanceCheckinBloc(gh<_i549.AttendanceCheckinService>()));
    gh.factory<_i607.AccountCubit>(() => _i607.AccountCubit(
          gh<_i840.LocalService>(),
          gh<_i644.ApiClient>(),
        ));
    gh.lazySingleton<_i806.BootstrapCubit>(() => _i806.BootstrapCubit(
          gh<_i840.LocalService>(),
          gh<_i239.BuildConfig>(),
        ));
    gh.lazySingleton<_i169.TeacherService>(
        () => _i169.TeacherServiceImplement(gh<_i644.ApiClient>()));
    gh.lazySingleton<_i566.ScheduleService>(
        () => _i566.ScheduleServiceImplement(gh<_i644.ApiClient>()));
    gh.factory<_i734.RegisterFaceBloc>(() => _i734.RegisterFaceBloc(
          gh<_i840.LocalService>(),
          gh<_i106.HiveService>(),
        ));
    gh.lazySingleton<_i276.DepartmentService>(
        () => _i276.DepartmentServiceImplement(gh<_i644.ApiClient>()));
    gh.lazySingleton<_i607.DeviceService>(
        () => _i607.DeviceServiceImplement(gh<_i644.ApiClient>()));
    gh.lazySingleton<_i148.TimeSlotService>(
        () => _i148.TimeSlotServiceImplement(gh<_i644.ApiClient>()));
    gh.lazySingleton<_i1001.RoomSessionService>(
        () => _i1001.RoomSessionServiceImplement(gh<_i644.ApiClient>()));
    gh.lazySingleton<_i141.DeviceRequestService>(
        () => _i141.DeviceRequestServiceImplement(gh<_i644.ApiClient>()));
    gh.factory<_i371.TeacherBloc>(
        () => _i371.TeacherBloc(gh<_i169.TeacherService>()));
    gh.lazySingleton<_i368.AuthenticationService>(
        () => _i368.AuthenticationServiceImplement(gh<_i644.ApiClient>()));
    gh.factory<_i981.DomainBloc>(
        () => _i981.DomainBloc(gh<_i840.LocalService>()));
    gh.factory<_i447.ServerSettingCubit>(
        () => _i447.ServerSettingCubit(gh<_i840.LocalService>()));
    gh.singleton<_i664.AttendanceReportCubit>(
        () => _i664.AttendanceReportCubit(gh<_i840.LocalService>()));
    gh.lazySingleton<_i492.RoomService>(
        () => _i492.RoomServiceImplement(gh<_i644.ApiClient>()));
    gh.lazySingleton<_i687.UserService>(() => _i687.UserServiceImplement(
          gh<_i644.ApiClient>(),
          gh<_i840.LocalService>(),
        ));
    gh.lazySingleton<_i691.StudentGroupService>(
        () => _i691.StudentGroupServiceImplement(gh<_i644.ApiClient>()));
    gh.lazySingleton<_i513.LoggingService>(() => _i513.LoggingServiceImplement(
          gh<_i644.ApiClient>(),
          gh<_i840.LocalService>(),
        ));
    gh.lazySingleton<_i102.AttendanceHistoryService>(
        () => _i102.AttendanceHistoryServiceImpl(gh<_i644.ApiClient>()));
    gh.lazySingleton<_i440.SessionService>(
        () => _i440.SessionServiceImplement(gh<_i644.ApiClient>()));
    gh.lazySingleton<_i995.CourseBloc>(
        () => _i995.CourseBloc(gh<_i256.CourseService>()));
    gh.factory<_i836.ScheduleBloc>(
        () => _i836.ScheduleBloc(gh<_i566.ScheduleService>()));
    gh.factory<_i309.CheckingBloc>(() => _i309.CheckingBloc(
          gh<_i840.LocalService>(),
          gh<_i578.AppBloc>(),
        ));
    gh.factory<_i775.SettingCubit>(() => _i775.SettingCubit(
          gh<_i840.LocalService>(),
          gh<_i687.UserService>(),
        ));
    gh.factory<_i858.DepartmentBloc>(
        () => _i858.DepartmentBloc(gh<_i276.DepartmentService>()));
    gh.factory<_i1029.StudentBloc>(() => _i1029.StudentBloc(
          gh<_i687.UserService>(),
          gh<_i106.HiveService>(),
        ));
    gh.factory<_i542.SessionManagementCubit>(
        () => _i542.SessionManagementCubit(gh<_i440.SessionService>()));
    gh.factory<_i496.AttendanceHistoryBloc>(() =>
        _i496.AttendanceHistoryBloc(gh<_i102.AttendanceHistoryService>()));
    gh.factory<_i905.RoomSessionBloc>(() => _i905.RoomSessionBloc(
          gh<_i1001.RoomSessionService>(),
          gh<_i141.DeviceRequestService>(),
          gh<_i840.LocalService>(),
        ));
    gh.factory<_i850.StudentGroupCubit>(() => _i850.StudentGroupCubit(
          gh<_i691.StudentGroupService>(),
          gh<_i276.DepartmentService>(),
          gh<_i169.TeacherService>(),
        ));
    gh.factory<_i257.RoomBloc>(() => _i257.RoomBloc(gh<_i492.RoomService>()));
    gh.factory<_i128.LoginBloc>(() => _i128.LoginBloc(
          gh<_i368.AuthenticationService>(),
          gh<_i840.LocalService>(),
        ));
    gh.factory<_i762.DevicePermissionCubit>(() => _i762.DevicePermissionCubit(
          gh<_i141.DeviceRequestService>(),
          gh<_i840.LocalService>(),
        ));
    return this;
  }
}

class _$InjectableModule extends _i754.InjectableModule {}
