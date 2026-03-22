import 'package:face_time_keeping/common/api_client/data_state.dart';
import 'package:face_time_keeping/common/enums/request_status.dart';
import 'package:face_time_keeping/data/remote/department_service.dart';
import 'package:face_time_keeping/pages/department/bloc/department_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

@injectable
class DepartmentBloc extends Cubit<DepartmentState> {
  DepartmentBloc(this._departmentService) : super(DepartmentState());

  final DepartmentService _departmentService;

  Future<void> loadDepartments() async {
    emit(state.copyWith(requestStatus: RequestStatus.requesting));
    final result = await _departmentService.getDepartments();
    if (result.isSuccess) {
      emit(state.copyWith(
        requestStatus: RequestStatus.success,
        departments: result.data ?? [],
      ));
    } else {
      emit(state.copyWith(
        requestStatus: RequestStatus.failed,
        message: result.error ?? 'Failed to load departments',
      ));
    }
  }

  Future<void> createDepartment({
    required String code,
    required String name,
  }) async {
    emit(state.copyWith(requestStatus: RequestStatus.requesting));
    final result = await _departmentService.createDepartment(
      code: code,
      name: name,
    );
    if (result.isSuccess) {
      emit(state.copyWith(
        requestStatus: RequestStatus.success,
        selectedDepartment: result.data,
      ));
      await loadDepartments();
    } else {
      emit(state.copyWith(
        requestStatus: RequestStatus.failed,
        message: result.error ?? 'Failed to create department',
      ));
    }
  }

  Future<void> updateDepartment({
    required String id,
    String? code,
    String? name,
  }) async {
    emit(state.copyWith(requestStatus: RequestStatus.requesting));
    final result = await _departmentService.updateDepartment(
      id,
      code: code,
      name: name,
    );
    if (result.isSuccess) {
      emit(state.copyWith(
        requestStatus: RequestStatus.success,
        selectedDepartment: result.data,
      ));
      await loadDepartments();
    } else {
      emit(state.copyWith(
        requestStatus: RequestStatus.failed,
        message: result.error ?? 'Failed to update department',
      ));
    }
  }

  Future<bool> deleteDepartment(String id) async {
    emit(state.copyWith(requestStatus: RequestStatus.requesting));
    final result = await _departmentService.deleteDepartment(id);
    if (result.isSuccess) {
      emit(state.copyWith(requestStatus: RequestStatus.success));
      await loadDepartments();
      return true;
    } else {
      emit(state.copyWith(
        requestStatus: RequestStatus.failed,
        message: result.error ?? 'Failed to delete department',
      ));
      return false;
    }
  }
}
