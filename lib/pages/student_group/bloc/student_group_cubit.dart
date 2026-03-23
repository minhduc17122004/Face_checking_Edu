import 'package:face_time_keeping/common/api_client/data_state.dart';
import 'package:face_time_keeping/common/enums/request_status.dart';
import 'package:face_time_keeping/data/remote/student_group_service.dart';
import 'package:face_time_keeping/data/remote/department_service.dart';
import 'package:face_time_keeping/data/remote/teacher_service.dart';
import 'package:face_time_keeping/pages/student_group/bloc/student_group_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

@injectable
class StudentGroupCubit extends Cubit<StudentGroupState> {
  StudentGroupCubit(
    this._studentGroupService,
    this._departmentService,
    this._teacherService,
  ) : super(StudentGroupState());

  final StudentGroupService _studentGroupService;
  final DepartmentService _departmentService;
  final TeacherService _teacherService;

  Future<void> loadStudentGroups() async {
    emit(state.copyWith(requestStatus: RequestStatus.requesting));
    final result = await _studentGroupService.getStudentGroups(limit: 500);
    if (result.isSuccess) {
      emit(state.copyWith(
        requestStatus: RequestStatus.success,
        studentGroups: result.data ?? [],
      ));
    } else {
      emit(state.copyWith(
        requestStatus: RequestStatus.failed,
        message: result.error ?? 'Failed to load student groups',
      ));
    }
  }

  Future<void> loadFormData({String? departmentId}) async {
    emit(state.copyWith(requestStatus: RequestStatus.requesting));
    
    // Load departments
    final deptResult = await _departmentService.getDepartments();
    
    // Load teachers (optionally filtered by department)
    final teacherResult = await _teacherService.getTeachers(
      limit: 500,
      departmentId: departmentId,
    );
    
    emit(state.copyWith(
      requestStatus: RequestStatus.success,
      departments: deptResult.data ?? [],
      teachers: teacherResult.data ?? [],
    ));
  }

  Future<void> loadTeachers(String? departmentId) async {
    // Only fetch if deptId is provided, otherwise clear
    if (departmentId == null) {
      emit(state.copyWith(teachers: []));
      return;
    }

    final result = await _teacherService.getTeachers(
      limit: 500,
      departmentId: departmentId,
    );
    
    if (result.isSuccess) {
      emit(state.copyWith(
        teachers: result.data ?? [],
      ));
    } else {
      emit(state.copyWith(teachers: []));
    }
  }

  Future<bool> createStudentGroup({
    String? code,
    required String name,
    String? departmentId,
    String? advisorId,
  }) async {
    emit(state.copyWith(requestStatus: RequestStatus.requesting));
    final result = await _studentGroupService.createStudentGroup(
      code: code,
      name: name,
      departmentId: departmentId,
      advisorId: advisorId,
    );
    if (result.isSuccess) {
      emit(state.copyWith(
        requestStatus: RequestStatus.success,
        selectedStudentGroup: result.data,
      ));
      await loadStudentGroups();
      return true;
    } else {
      emit(state.copyWith(
        requestStatus: RequestStatus.failed,
        message: result.error ?? 'Failed to create student group',
      ));
      return false;
    }
  }

  Future<bool> updateStudentGroup(
    String id, {
    String? code,
    String? name,
    String? departmentId,
    String? advisorId,
  }) async {
    emit(state.copyWith(requestStatus: RequestStatus.requesting));
    final result = await _studentGroupService.updateStudentGroup(
      id,
      code: code,
      name: name,
      departmentId: departmentId,
      advisorId: advisorId,
    );
    if (result.isSuccess) {
      emit(state.copyWith(
        requestStatus: RequestStatus.success,
        selectedStudentGroup: result.data,
      ));
      await loadStudentGroups();
      return true;
    } else {
      emit(state.copyWith(
        requestStatus: RequestStatus.failed,
        message: result.error ?? 'Failed to update student group',
      ));
      return false;
    }
  }

  Future<bool> deleteStudentGroup(String id) async {
    emit(state.copyWith(requestStatus: RequestStatus.requesting));
    final result = await _studentGroupService.deleteStudentGroup(id);
    if (result.isSuccess) {
      emit(state.copyWith(requestStatus: RequestStatus.success));
      await loadStudentGroups();
      return true;
    } else {
      emit(state.copyWith(
        requestStatus: RequestStatus.failed,
        message: result.error ?? 'Failed to delete student group',
      ));
      return false;
    }
  }
}
