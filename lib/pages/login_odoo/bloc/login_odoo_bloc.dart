import 'dart:io';

import 'package:face_native/face_native.dart';
import 'package:face_time_keeping/common/api_client/data_state.dart';
import 'package:face_time_keeping/common/enums/request_status.dart';
import 'package:face_time_keeping/common/enums/server_type.dart';
import 'package:face_time_keeping/common/utils/log_util.dart';
import 'package:face_time_keeping/common/utils/sync_jobs_util.dart';
import 'package:face_time_keeping/data/local/hive_service.dart';
import 'package:face_time_keeping/data/local/local_service.dart';
import 'package:face_time_keeping/data/remote/authentication/login_request.dart';
import 'package:face_time_keeping/data/remote/authentication_service.dart';
import 'package:face_time_keeping/di/injection.dart';
import 'package:face_time_keeping/pages/login_odoo/bloc/login_odoo_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

@Injectable()
class LoginOdooBloc extends Cubit<LoginOdooState> {
  LoginOdooBloc(this._authenticationService, this._localService)
      : super(LoginOdooState());
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
      emit(state.copyWith(requestStatus: RequestStatus.requesting));
      final database = await _localService.getOdooDbName();
      if (database.isEmpty ||
          state.username == null ||
          state.password == null) {
        emit(state.copyWith(
            requestStatus: RequestStatus.failed,
            message: "Vui lòng nhập đầy đủ thông tin"));
        return;
      }
      final userId = await _authenticationService.authenticateDatabase(
          state.username!, state.password!, database);
      if (userId.isSuccess) {
        _localService.saveUserId(userId.data!);
      } else {
        emit(state.copyWith(
            requestStatus: RequestStatus.failed, message: userId.error));
        return;
      }
      final result = await _authenticationService.login(LoginRequest(
          username: state.username,
          password: state.password,
          database: database));
      if (result.isSuccess) {
        _localService.saveOdooToken(result.data?.token);
        _localService.saveLoginOdooId(state.username);

        // Get old tenant ID before creating/getting new one
        final oldTenantId =
            await _localService.getTenantId().catchError((_) => -1);

        final tenantId = await _localService.getTenantIdOrSaveTenant(
            _localService.getOdooDomain(), database);
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

        // Check for unsynced local employees
        final hasUnsynced = await _localService.hasUnsyncedLocalEmployees();
        emit(state.copyWith(
          requestStatus: RequestStatus.success,
          hasUnsyncedEmployees: hasUnsynced,
        ));
      } else {
        emit(state.copyWith(
            requestStatus: RequestStatus.failed, message: result.error));
      }
    } catch (e) {
      await pushLog('Error in onLogin: $e');
      emit(state.copyWith(requestStatus: RequestStatus.failed));
    }
  }

  Future<void> syncLocalEmployeesToServer() async {
    await SyncJobsUtil.syncEmployeeDataNow();
  }
}
