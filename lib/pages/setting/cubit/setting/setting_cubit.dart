import 'package:bloc/bloc.dart';
import 'package:face_time_keeping/common/api_client/data_state.dart';
import 'package:face_time_keeping/data/models/register_user_request.dart';
import 'package:face_time_keeping/data/local/local_service.dart';
import 'package:face_time_keeping/data/models/student_request.dart';
import 'package:face_time_keeping/data/remote/user_service.dart';
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

  String getServerUrl() {
    try {
      return _localService.getServerUrl();
    } catch (e) {
      return '';
    }
  }

  Future<String> getUserRole() async {
    try {
      final role = _localService.getUserRole();
      emit(state.copyWith(userRole: role));
      return role;
    } catch (e) {
      return '';
    }
  }

  Future<bool> hasUnsyncedLocalStudents() async {
    return await _localService.hasUnsyncedLocalStudents();
  }

  Future<DataState> syncLocalStudentsToServer() async {
    try {
      final unsyncedStudents = await _localService.getUnsyncedLocalStudents();
      if (unsyncedStudents.isEmpty) {
        return const DataSuccess<String>('Không có dữ liệu để đồng bộ');
      }

      // Convert Person objects to StudentRequest objects
      final studentRequests = unsyncedStudents.map((person) {
        return StudentRequest(
          name: person.name ?? 'Unknown',
          pin: person.pin ?? '',
          jobTitle: person.jobTitle?.toString() ?? '',
        );
      }).toList();

      final request = CreateStudentBatchRequest(students: studentRequests);
      final result = await _userService.registerStudents(request);

      if (result.isSuccess) {
        // Mark all synced students as synced in local DB
        for (final person in unsyncedStudents) {
          await _localService.setPersonSynced(person.studentId);
        }

        // Fetch all students from server and update local DB
        final serverType = await _localService.getServerType();
        final serverName = serverType?.label ?? 'Server';

        final studentsResult = await _userService.getStudents();
        if (studentsResult.isSuccess && studentsResult.data != null) {
          await _localService.syncStudentsFromServer(
            studentsResult.data!,
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

  Future<DataState<RegisterUserResponse>> registerUser(
      RegisterUserRequest request) async {
    return await _userService.registerUser(request);
  }
}
