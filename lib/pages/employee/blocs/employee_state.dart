import 'package:face_time_keeping/entities/employee.dart';

import '../../widgets/content_widget.dart';

class EmployeeState {
  final List<Employee>? employees;
  final List<Employee>? employeesFromServer;
  final DataSourceStatus status;
  final DataSourceStatus serverStatus;
  final String? error;
  final String? syncMessage;

  const EmployeeState({
    this.employees,
    this.employeesFromServer,
    this.status = DataSourceStatus.initial,
    this.serverStatus = DataSourceStatus.initial,
    this.error,
    this.syncMessage,
  });

  EmployeeState copyWith({
    List<Employee>? employees,
    List<Employee>? employeesFromServer,
    DataSourceStatus? status,
    DataSourceStatus? serverStatus,
    String? error,
    String? syncMessage,
  }) {
    return EmployeeState(
      employees: employees ?? this.employees,
      employeesFromServer: employeesFromServer ?? this.employeesFromServer,
      status: status ?? this.status,
      serverStatus: serverStatus ?? this.serverStatus,
      error: error,
      syncMessage: syncMessage,
    );
  }
}
