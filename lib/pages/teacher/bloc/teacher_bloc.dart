import 'package:face_time_keeping/common/api_client/data_state.dart';
import 'package:face_time_keeping/common/enums/request_status.dart';
import 'package:face_time_keeping/data/remote/teacher_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import 'teacher_state.dart';

@injectable
class TeacherBloc extends Cubit<TeacherState> {
  TeacherBloc(this._teacherService) : super(TeacherState());

  final TeacherService _teacherService;

  Future<void> loadTeachers({String? departmentId}) async {
    emit(state.copyWith(requestStatus: RequestStatus.requesting));
    final result = await _teacherService.getTeachers(departmentId: departmentId);
    if (result.isSuccess) {
      emit(state.copyWith(
        requestStatus: RequestStatus.success,
        teachers: result.data ?? [],
      ));
    } else {
      emit(state.copyWith(
        requestStatus: RequestStatus.failed,
        message: result.error ?? 'Failed to load teachers',
      ));
    }
  }

  Future<void> assignTeacherToDepartment({
    required int teacherId,
    required String departmentId,
  }) async {
    emit(state.copyWith(requestStatus: RequestStatus.requesting));
    final result = await _teacherService.assignDepartment(teacherId, departmentId);
    if (result.isSuccess) {
      emit(state.copyWith(requestStatus: RequestStatus.success));
      await loadTeachers(departmentId: departmentId);
    } else {
      emit(state.copyWith(
        requestStatus: RequestStatus.failed,
        message: result.error ?? 'Failed to assign teacher',
      ));
    }
  }

  Future<void> removeTeacherFromDepartment(int teacherId) async {
    emit(state.copyWith(requestStatus: RequestStatus.requesting));
    final result = await _teacherService.removeDepartment(teacherId);
    if (result.isSuccess) {
      emit(state.copyWith(requestStatus: RequestStatus.success));
      await loadTeachers();
    } else {
      emit(state.copyWith(
        requestStatus: RequestStatus.failed,
        message: result.error ?? 'Failed to remove teacher',
      ));
    }
  }
}
