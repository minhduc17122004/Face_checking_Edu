import '../../../entities/employee.dart';

class DidChangeEmployeeEvent {
  Employee? employee;
  DidChangeEmployeeEvent(this.employee);
}