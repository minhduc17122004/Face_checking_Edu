import 'package:face_time_keeping/common/enums/request_status.dart';
import 'package:face_time_keeping/entities/department.dart';

class DepartmentState {
  final RequestStatus requestStatus;
  final List<Department> departments;
  final String? message;
  final Department? selectedDepartment;

  DepartmentState({
    this.requestStatus = RequestStatus.initial,
    this.departments = const [],
    this.message,
    this.selectedDepartment,
  });

  DepartmentState copyWith({
    RequestStatus? requestStatus,
    List<Department>? departments,
    String? message,
    Department? selectedDepartment,
  }) {
    return DepartmentState(
      requestStatus: requestStatus ?? this.requestStatus,
      departments: departments ?? this.departments,
      message: message,
      selectedDepartment: selectedDepartment ?? this.selectedDepartment,
    );
  }
}
