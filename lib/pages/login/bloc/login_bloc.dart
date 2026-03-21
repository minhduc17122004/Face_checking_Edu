import 'dart:io';
import 'dart:developer';

import 'package:face_native/face_native.dart';
import 'package:face_time_keeping/common/api_client/data_state.dart';
import 'package:face_time_keeping/common/enums/request_status.dart';
import 'package:face_time_keeping/common/enums/server_type.dart';
import 'package:face_time_keeping/common/utils/log_util.dart';
import 'package:face_time_keeping/common/utils/sync_jobs_util.dart';
import 'package:face_time_keeping/configs/build_config.dart';
import 'package:face_time_keeping/data/local/hive_service.dart';
import 'package:face_time_keeping/data/local/local_service.dart';
import 'package:face_time_keeping/data/remote/authentication/login_request.dart';
import 'package:face_time_keeping/data/remote/authentication_service.dart';
import 'package:face_time_keeping/di/injection.dart';
import 'package:face_time_keeping/pages/login/bloc/login_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

@Injectable()
class LoginBloc extends Cubit<LoginState> {
  LoginBloc(this._authenticationService, this._localService)
      : super(LoginState());
  final AuthenticationService _authenticationService;
  final LocalService _localService;

  void onChangeUsername(String? value) {
    emit(state.copyWith(username: value));
  }

  void onChangePass(String? value) {
    emit(state.copyWith(password: value));
  }

  int extractUserId(Map<String, dynamic> decoded) {
    // final Map<String, dynamic> decoded = json.decode(jsonString);
    return decoded['user_settings']['user_id']['id'] as int;
  }

  Future<void> onLogin() async {
    try {
      log('LoginBloc.onLogin started | username=${state.username}');
      emit(state.copyWith(requestStatus: RequestStatus.requesting));

      if (state.username == null || state.password == null) {
        log('LoginBloc.onLogin validation failed: missing username or password');
        emit(state.copyWith(
            requestStatus: RequestStatus.failed,
            message: "Vui lòng nhập đầy đủ thông tin"));
        return;
      }

      final configuredBaseUrl = getIt<BuildConfig>().kBaseUrl.trim();
      final fallbackBaseUrl = _localService.getServerUrl().trim();
      final activeBaseUrl =
          configuredBaseUrl.isNotEmpty ? configuredBaseUrl : fallbackBaseUrl;
      log('LoginBloc.onLogin activeBaseUrl=$activeBaseUrl');

      log('LoginBloc.onLogin calling AuthenticationService.login');
      final result = await _authenticationService
          .login(LoginRequest(email: state.username, password: state.password));
      log('LoginBloc.onLogin login returned | isSuccess=${result.isSuccess}');

      if (result.isSuccess) {
        final token = result.data?.token;
        final refreshToken = result.data?.refreshToken;
        final userEmail = result.data?.user?.email ?? state.username;
        final userFullName = result.data?.user?.fullName?.trim();
        final userIdStr = result.data?.user?.id ?? "1";
        final avatarUrl = result.data?.user?.avatarUrl;

        _localService.saveAuthToken(token);
        _localService.saveRefreshToken(refreshToken);
        // Lưu role/email tương ứng
        _localService.saveLoginId(userEmail);
        _localService.saveUserEmail(userEmail);
        _localService.saveUserFullName(userFullName);
        _localService.saveUserId(userIdStr.hashCode.abs());

        if (avatarUrl != null && avatarUrl.isNotEmpty) {
          _localService.saveAvatarPath(activeBaseUrl + avatarUrl);
        } else {
          _localService.saveAvatarPath("");
        }

        // Save user role from login response (always — independent of avatar)
        final userRole = result.data?.user?.role;
        _localService.saveUserRole(userRole);

        // Sử dụng một database dummy cho cấu trúc cũ
        final String database = "fastapi_db";
        await _localService.saveDatabaseName(database);

        // Get old tenant ID before creating/getting new one
        final oldTenantId =
            await _localService.getTenantId().catchError((_) => -1);
        log('LoginBloc.onLogin oldTenantId=$oldTenantId');

        final tenantId = await _localService.getTenantIdOrSaveTenant(
            activeBaseUrl, database);
        log('LoginBloc.onLogin resolved tenantId=$tenantId');
        _localService.saveTenantId(tenantId);

        final tempServerType = await _localService.getTempServerType();
        _localService.saveServerType(tempServerType ?? ServerType.none);
        await _localService.initDefaultData();

        // if platform == android
        if (Platform.isAndroid) {
          await FaceNative().initObjectBox(tenantId.toString());
        }

        // Initialize new tenant Hive boxes
        await getIt<HiveService>().init(tenantId.toString());

        // Clone data from old tenant if different
        if (oldTenantId != -1 && oldTenantId != tenantId) {
          await _localService.cloneDataFromPreviousTenant(
              oldTenantId, tenantId);
        }

        // Check for unsynced local students
        final hasUnsynced = await _localService.hasUnsyncedLocalStudents();
        log('LoginBloc.onLogin completed | hasUnsyncedStudents=$hasUnsynced');
        emit(state.copyWith(
          requestStatus: RequestStatus.success,
          hasUnsyncedStudents: hasUnsynced,
        ));
      } else {
        log('LoginBloc.onLogin failed from API | error=${result.error}');
        emit(state.copyWith(
            requestStatus: RequestStatus.failed, message: result.error));
      }
    } catch (e, s) {
      log('LoginBloc.onLogin exception: $e\n$s');
      await pushLog('Error in onLogin: $e\n$s');
      emit(state.copyWith(requestStatus: RequestStatus.failed));
    }
  }

  Future<void> syncLocalStudentsToServer() async {
    log('LoginBloc.syncLocalStudentsToServer started');
    await SyncJobsUtil.syncStudentDataNow();
    log('LoginBloc.syncLocalStudentsToServer finished');
  }
}
