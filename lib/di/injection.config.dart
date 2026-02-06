// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// InjectableConfigGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:dio/dio.dart' as _i5;
import 'package:face_time_keeping/common/api_client/api_client.dart' as _i9;
import 'package:face_time_keeping/configs/build_config.dart' as _i3;
import 'package:face_time_keeping/data/local/hive_service.dart' as _i6;
import 'package:face_time_keeping/data/local/keychain/shared_prefs.dart' as _i8;
import 'package:face_time_keeping/data/local/local_service.dart' as _i12;
import 'package:face_time_keeping/data/remote/authentication_service.dart'
    as _i11;
import 'package:face_time_keeping/data/remote/logging_service.dart' as _i13;
import 'package:face_time_keeping/data/remote/user_service.dart' as _i17;
import 'package:face_time_keeping/di/modules.dart' as _i24;
import 'package:face_time_keeping/pages/bloc/app_bloc.dart' as _i10;
import 'package:face_time_keeping/pages/bootstrap/bootstrap_cubit.dart' as _i19;
import 'package:face_time_keeping/pages/checking/bloc/checking_bloc.dart'
    as _i20;
import 'package:face_time_keeping/pages/domain/bloc/domain_bloc.dart' as _i21;
import 'package:face_time_keeping/pages/employee/blocs/employee_bloc.dart'
    as _i22;
import 'package:face_time_keeping/pages/login_odoo/bloc/login_odoo_bloc.dart'
    as _i14;
import 'package:face_time_keeping/pages/register_face/bloc/register_face_bloc.dart'
    as _i15;
import 'package:face_time_keeping/pages/setting/cubit/attendance_report_cubit.dart'
    as _i18;
import 'package:face_time_keeping/pages/setting/cubit/server_setting/server_setting_cubit.dart'
    as _i16;
import 'package:face_time_keeping/pages/setting/cubit/setting/setting_cubit.dart'
    as _i23;
import 'package:face_time_keeping/utils/csv_util.dart' as _i4;
import 'package:get_it/get_it.dart' as _i1;
import 'package:injectable/injectable.dart' as _i2;
import 'package:shared_preferences/shared_preferences.dart' as _i7;

const String _prod = 'prod';

extension GetItInjectableX on _i1.GetIt {
// initializes the registration of main-scope dependencies inside of GetIt
  Future<_i1.GetIt> init({
    String? environment,
    _i2.EnvironmentFilter? environmentFilter,
  }) async {
    final gh = _i2.GetItHelper(
      this,
      environment,
      environmentFilter,
    );
    final injectableModule = _$InjectableModule();
    gh.lazySingleton<_i3.BuildConfig>(
      () => _i3.BuildConfigProd(),
      registerFor: {_prod},
    );
    gh.lazySingleton<_i4.CsvUtil>(() => _i4.CsvUtil());
    gh.lazySingleton<_i5.Dio>(() => injectableModule.dio);
    gh.lazySingleton<_i6.HiveService>(() => _i6.HiveServiceImplement());
    await gh.factoryAsync<_i7.SharedPreferences>(
      () => injectableModule.prefs,
      preResolve: true,
    );
    gh.lazySingleton<_i8.SharedPrefs>(
        () => _i8.SharedPrefs(gh<_i7.SharedPreferences>()));
    gh.singleton<_i9.ApiClient>(() => _i9.ApiClient(dio: gh<_i5.Dio>()));
    gh.singleton<_i10.AppBloc>(() => _i10.AppBloc(gh<_i6.HiveService>()));
    gh.lazySingleton<_i11.AuthenticationService>(
        () => _i11.AuthenticationServiceImplement(gh<_i9.ApiClient>()));
    gh.lazySingleton<_i12.LocalService>(() => _i12.LocalServiceImplement(
          gh<_i8.SharedPrefs>(),
          gh<_i9.ApiClient>(),
          gh<_i6.HiveService>(),
          gh<_i4.CsvUtil>(),
        ));
    gh.lazySingleton<_i13.LoggingService>(() => _i13.LoggingServiceImplement(
          gh<_i9.ApiClient>(),
          gh<_i12.LocalService>(),
        ));
    gh.factory<_i14.LoginOdooBloc>(() => _i14.LoginOdooBloc(
          gh<_i11.AuthenticationService>(),
          gh<_i12.LocalService>(),
        ));
    gh.factory<_i15.RegisterFaceBloc>(() => _i15.RegisterFaceBloc(
          gh<_i12.LocalService>(),
          gh<_i6.HiveService>(),
        ));
    gh.factory<_i16.ServerSettingCubit>(
        () => _i16.ServerSettingCubit(gh<_i12.LocalService>()));
    gh.lazySingleton<_i17.UserService>(() => _i17.UserServiceImplement(
          gh<_i9.ApiClient>(),
          gh<_i12.LocalService>(),
        ));
    gh.singleton<_i18.AttendanceReportCubit>(
        () => _i18.AttendanceReportCubit(gh<_i12.LocalService>()));
    gh.lazySingleton<_i19.BootstrapCubit>(() => _i19.BootstrapCubit(
          gh<_i12.LocalService>(),
          gh<_i3.BuildConfig>(),
          gh<_i11.AuthenticationService>(),
        ));
    gh.factory<_i20.CheckingBloc>(() => _i20.CheckingBloc(
          gh<_i12.LocalService>(),
          gh<_i10.AppBloc>(),
        ));
    gh.factory<_i21.DomainBloc>(() => _i21.DomainBloc(gh<_i12.LocalService>()));
    gh.factory<_i22.EmployeeBloc>(() => _i22.EmployeeBloc(
          gh<_i17.UserService>(),
          gh<_i6.HiveService>(),
        ));
    gh.factory<_i23.SettingCubit>(() => _i23.SettingCubit(
          gh<_i12.LocalService>(),
          gh<_i17.UserService>(),
        ));
    return this;
  }
}

class _$InjectableModule extends _i24.InjectableModule {}
