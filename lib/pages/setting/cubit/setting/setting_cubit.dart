import 'package:bloc/bloc.dart';
import 'package:face_time_keeping/common/api_client/data_state.dart';
import 'package:face_time_keeping/data/local/local_service.dart';
import 'package:face_time_keeping/data/models/create_employees_model.dart';
import 'package:face_time_keeping/data/remote/authentication_service.dart';
import 'package:face_time_keeping/data/remote/user_service.dart';
import 'package:face_time_keeping/di/injection.dart';
import 'package:face_time_keeping/entities/sync_face_schedule.dart';
import 'package:face_time_keeping/pages/setting/cubit/setting/setting_state.dart';
import 'package:flutter/material.dart';
import 'package:face_time_keeping/common/enums/server_type.dart';
import 'package:injectable/injectable.dart';

@injectable
class SettingCubit extends Cubit<SettingState> {
  final LocalService _localService;
  final UserService _userService;

  SettingCubit(this._localService, this._userService) : super(SettingState());

  Future<SyncFaceSchedule?> getSyncFaceSchedule() async {
    try {
      final sched = await _localService.getSyncFaceSchedule();
      emit(state.copyWith(syncFaceSchedule: sched));
      return sched;
    } catch (e) {
      return null;
    }
  }

  Future<void> saveSyncFaceSchedule(SyncFaceSchedule schedule) async {
    emit(state.copyWith(isLoading: true));
    try {
      await _localService.saveSyncFaceSchedule(schedule);
      emit(state.copyWith(syncFaceSchedule: schedule, isLoading: false));
    } catch (e) {
      emit(state.copyWith(isLoading: false));
      rethrow;
    }
  }

  Future<void> clearSyncFaceSchedule() async {
    emit(state.copyWith(isLoading: true));
    try {
      await _localService.clearSyncFaceSchedule();
      emit(state.copyWith(syncFaceSchedule: null, isLoading: false));
    } catch (e) {
      emit(state.copyWith(isLoading: false));
      rethrow;
    }
  }

  Future<DataState> pushFaceData() async {
    return await _userService.pushFaceData();
  }

  Future<DataState> pullFaceData() async {
    return await _userService.pullFaceData();
  }

  Future<DataState> syncCheckInOutData() async {
    return await _userService.syncCheckInOutData();
  }

  Future<Map<String, TimeOfDay>> getShiftTimes() async {
    return await _localService.getShiftTimes();
  }

  Future<void> saveShiftTimes({
    required TimeOfDay morningStart,
    required TimeOfDay morningEnd,
    required TimeOfDay afternoonStart,
    required TimeOfDay afternoonEnd,
    required TimeOfDay nightStart,
    required TimeOfDay nightEnd,
  }) async {
    await _localService.saveShiftTimes(
      morningStart: morningStart,
      morningEnd: morningEnd,
      afternoonStart: afternoonStart,
      afternoonEnd: afternoonEnd,
      nightStart: nightStart,
      nightEnd: nightEnd,
    );
  }

  Future<ServerType?> getServerType() async {
    try {
      final s = await _localService.getServerType();
      emit(state.copyWith(serverType: s));
      return s;
    } catch (e) {
      return null;
    }
  }

  Future<bool> hasUnsyncedLocalEmployees() async {
    return await _localService.hasUnsyncedLocalEmployees();
  }

  Future<DataState> syncLocalEmployeesToServer() async {
    try {
      final unsyncedEmployees = await _localService.getUnsyncedLocalEmployees();
      if (unsyncedEmployees.isEmpty) {
        return const DataSuccess<String>('Không có dữ liệu để đồng bộ');
      }

      // Convert Person objects to EmployeeRequest objects
      final employeeRequests = unsyncedEmployees.map((person) {
        return EmployeeRequest(
          name: person.name ?? 'Unknown',
          pin: person.pin ?? '',
          jobTitle: person.jobTitle?.toString() ?? '',
        );
      }).toList();

      final request = CreateEmployeeBatchRequest(employees: employeeRequests);
      final result = await _userService.registerEmployees(request);

      if (result.isSuccess) {
        // Mark all synced employees as synced in local DB
        for (final person in unsyncedEmployees) {
          await _localService.setPersonSynced(person.employeeId);
        }

        // Fetch all employees from server and update local DB
        final serverType = await _localService.getServerType();
        final serverName = serverType?.label ?? 'Server';

        final employeesResult = await _userService.getEmployees();
        if (employeesResult.isSuccess && employeesResult.data != null) {
          await _localService.syncEmployeesFromServer(
            employeesResult.data!,
            serverName,
          );
        }

        return const DataSuccess<String>('Đồng bộ học sinh thành công');
      } else {
        return DataFailed<String>(result.error ?? 'Đồng bộ học sinh thất bại');
      }
    } catch (e) {
      return DataFailed<String>('Lỗi đồng bộ học sinh: $e');
    }
  }

  Future<void> logout() async {
    try {
      await getIt<AuthenticationService>().logout();
    } catch (_) {
      // Always clear local auth state even if remote logout fails.
    }
    _localService.saveAuthToken(null);
    _localService.saveLoginId(null);
    _localService.saveUserEmail(null);
    _localService.saveUserFullName(null);
  }
}
