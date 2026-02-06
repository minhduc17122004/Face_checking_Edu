import 'dart:async';
import 'dart:developer';

import 'package:face_native/face_native.dart';
import 'package:face_time_keeping/common/event/event_bus_event.dart';
import 'package:face_time_keeping/common/utils/extensions/string_extension.dart';
import 'package:face_time_keeping/common/utils/log_util.dart';
import 'package:face_time_keeping/common/utils/sync_jobs_util.dart';
import 'package:face_time_keeping/data/local/hive_service.dart';
import 'package:face_time_keeping/data/local/local_service.dart';
import 'package:face_time_keeping/data/remote/user_service.dart';
import 'package:face_time_keeping/entities/employee.dart';
import 'package:face_time_keeping/entities/person.dart';
import 'package:face_time_keeping/entities/register_employee.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../common/api_client/data_state.dart';
import '../../../common/event/event_bus_mixin.dart';
import '../../widgets/content_widget.dart';
import '../helper/event.dart';
import 'employee_state.dart';

@Injectable()
class EmployeeBloc extends Cubit<EmployeeState> with EventBusMixin {
  EmployeeBloc(this._userRepository, this._hiveService) : super(const EmployeeState()) {
    registerEventSubscriptions();
  }

  final UserService _userRepository;
  final HiveService _hiveService;
  final FaceNative _faceNative = FaceNative();
  List<Employee> _savedEmployees = [];
  List<Employee> _savedServerEmployees = [];
  List<StreamSubscription> _eventSubscriptions = [];

  @override
  Future<void> close() {
    cancelAllEventSubscriptions();
    return super.close();
  }

  void registerEventSubscriptions() {
    final e1 = listenEvent<DidChangeEmployeeEvent>((e) => _didUpdateEmp(e.employee));
    final e2 = listenEvent<SyncEmployeeEvent>((e) => _onSyncEmployeeComplete(e));
    _eventSubscriptions.addAll([e1, e2]);
  }

  void cancelAllEventSubscriptions() {
    _eventSubscriptions.forEach((sub) => sub.cancel());
    _eventSubscriptions.clear();
  }

  void init() {
    _fetchEmployees();
    // fetchServerEmployees();
  }

  void refresh() {
    _fetchEmployees();
    // fetchServerEmployees();
  }

  Future<void> fetchServerEmployees() async {
    try {
      emit(state.copyWith(serverStatus: DataSourceStatus.refreshing));
      final DataState<List<Employee>> result = await _userRepository.getEmployees();
      if (result.isSuccess) {
        _savedServerEmployees = result.data ?? [];
        emit(state.copyWith(
            employeesFromServer: result.data,
            serverStatus:
                (result.data ?? []).isEmpty ? DataSourceStatus.empty : DataSourceStatus.success));
      } else {
        emit(state.copyWith(serverStatus: DataSourceStatus.failed));
      }
    } catch (e) {
      await pushLog('Error in fetchServerEmployees: $e');
      emit(state.copyWith(serverStatus: DataSourceStatus.failed));
    }
  }

  Future<void> syncData() async {
    // await _userRepository.syncEmployeeData();
    await SyncJobsUtil.syncEmployeeDataNow();
  }

  void _didUpdateEmp(Employee? emp) {
    final List<Employee> newValues = List.from(state.employees ?? []);
    final index = newValues.indexWhere((element) => element.id == emp?.id);
    if (index >= 0) {
      newValues[index] = emp!;
      emit(state.copyWith(employees: newValues));
    }
  }

  Future<void> _onSyncEmployeeComplete(SyncEmployeeEvent event) async {
    // Only refresh data when sync completes (not for in_progress)
    if (event.status == 'in_progress') {
      return;
    }

    // Refresh Hive box to get data saved by background isolate
    await _hiveService.refreshPersonBox();

    // Refresh employee lists when background sync completes
    // refresh();
    Future.delayed(const Duration(seconds: 1), () => _fetchEmployees());
  }

  Future<void> onRefresh() async {
    emit(state.copyWith(status: DataSourceStatus.refreshing));
    _fetchEmployees();
  }

  Future<void> _fetchEmployees() async {
    try {
      final List<Person> result = await _hiveService.getAllPersons();
      final employees = List<Employee>.from(result.map((e) => e.toEmployee()));
      _savedEmployees = employees;
      emit(state.copyWith(
          employees: employees,
          status: employees.isEmpty ? DataSourceStatus.empty : DataSourceStatus.success));
    } catch (e) {
      await pushLog('Error in fetchEmployees: $e');
      emit(state.copyWith(status: DataSourceStatus.failed));
    }
  }

  void onSearch(String? text, {bool isServerTab = false}) {
    if (text?.isEmpty ?? true) {
      if (isServerTab) {
        emit(state.copyWith(employeesFromServer: _savedServerEmployees));
      } else {
        emit(state.copyWith(employees: _savedEmployees));
      }
      return;
    }
    final textLower = text!.removeVietnameseDiacritics().toLowerCase();
    log('textLower: $textLower');

    if (isServerTab) {
      final results = List<Employee>.from(_savedServerEmployees)
          .where((element) =>
              element.name.removeVietnameseDiacritics().contains(text.removeVietnameseDiacritics()))
          .toList();
      emit(state.copyWith(employeesFromServer: results));
    } else {
      final results = List<Employee>.from(_savedEmployees)
          .where((element) =>
              element.name.removeVietnameseDiacritics().contains(text.removeVietnameseDiacritics()))
          .toList();
      emit(state.copyWith(employees: results));
    }
  }

  Future<bool> onRegisterEmployee(RegisterEmployee registerEmployee, bool hasServerConfig) async {
    if (hasServerConfig) {
      return (await onRegisterEmployeeToServer(registerEmployee));
    } else {
      return (await onRegisterEmployeeLocal(registerEmployee));
    }
  }

  Future<bool> onRegisterEmployeeToServer(RegisterEmployee registerEmployee) async {
    final DataState<Employee> result = await _userRepository.registerEmployee(registerEmployee);
    if (result.isSuccess) {
      final List<Employee> newValues = List.from(state.employees ?? []);
      newValues.add(result.data!);
      final registerEmployee = RegisterEmployee(
        employeeId: result.data?.id,
        employeeName: result.data!.name,
        jobPosition: result.data!.jobTitle,
        pin: result.data?.pin ?? '',
        avatar: result.data?.avatar,
      );
      await onRegisterEmployeeLocal(registerEmployee);
      emit(state.copyWith(employeesFromServer: newValues, serverStatus: DataSourceStatus.success));
      return true;
    } else {
      emit(state.copyWith(
          serverStatus: DataSourceStatus.failed, error: result.error, employees: state.employees));
    }
    return false;
  }

  // Updated to save to local database
  Future<bool> onRegisterEmployeeLocal(RegisterEmployee registerEmployee) async {
    try {
      // Check for duplicate PIN
      final pin = registerEmployee.pin.trim();
      if (pin.isNotEmpty) {
        final existingEmployees = await _hiveService.getAllPersons();
        final duplicatePin = existingEmployees.any(
          (person) => person.pin?.trim() == pin,
        );

        if (duplicatePin) {
          emit(state.copyWith(
            status: DataSourceStatus.failed,
            error: 'Mã PIN "$pin" đã tồn tại. Vui lòng sử dụng mã PIN khác.',
            employees: state.employees,
          ));
          return false;
        }
      }

      await _hiveService.savePerson(Person(
        employeeId: registerEmployee.employeeId ??
            DateTime.now().millisecondsSinceEpoch ~/ 1000, // Generate a unique ID
        pin: registerEmployee.pin,
        name: registerEmployee.employeeName,
        jobTitle: registerEmployee.jobPosition,
        avatar: registerEmployee.avatar,
        updatedTime: DateTime.now(),
      ));
      _fetchEmployees();
      return true;
    } catch (e) {
      await pushLog('Error in onRegisterEmployee: $e');
      emit(state.copyWith(
          status: DataSourceStatus.failed,
          error: 'Lỗi khi đăng ký nhân viên: $e',
          employees: state.employees));
    }
    return false;
  }

  /// Remove an employee from local storage. Returns true if removed successfully.
  Future<bool> onRemoveEmployee(int? employeeId) async {
    if (employeeId == null) return false;
    try {
      await _hiveService.deletePerson(employeeId);
      _faceNative.removeImages(employeeId);
      await _fetchEmployees();
      return true;
    } catch (e) {
      await pushLog('Error in onRemoveEmployee: $e');
      emit(state.copyWith(
          status: DataSourceStatus.failed,
          error: 'Lỗi khi xóa nhân viên: $e',
          employees: state.employees));
      return false;
    }
  }

  Future<bool> onResetFace(int? employeeId) {
    if (employeeId == null) return Future.value(false);
    return _faceNative.removeImages(employeeId);
  }

  Future<void> onUpdatEmployeeInList(Employee employee, {bool isUpdatePin = false}) async {
    // Check for duplicate PIN when updating (exclude current employee)
    final pin = employee.pin?.trim() ?? '';
    if (pin.isNotEmpty) {
      final existingEmployees = await _hiveService.getAllPersons();
      final duplicatePin = existingEmployees.any((person) => person.pin?.trim() == pin);

      if (duplicatePin && isUpdatePin) {
        emit(state.copyWith(
          status: DataSourceStatus.failed,
          error: 'Mã PIN "$pin" đã tồn tại. Vui lòng sử dụng mã PIN khác.',
          employees: state.employees,
        ));
        return;
      }
    }

    await _hiveService.updatePerson(employee.toPerson());
    await _faceNative.updatePerson(employee.id, employee.name);
    final List<Employee> newValues = List.from(state.employees ?? []);
    final index = newValues.indexWhere((element) => element.id == employee.id);
    if (index >= 0) {
      newValues[index] = employee;
      emit(state.copyWith(employees: newValues, status: DataSourceStatus.success));
    }
  }
}
