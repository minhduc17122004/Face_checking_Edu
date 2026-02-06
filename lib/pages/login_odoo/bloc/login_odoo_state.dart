import 'package:face_time_keeping/common/enums/request_status.dart';

class LoginOdooState {
  String? username;
  String? password;
  String? message;
  RequestStatus requestStatus;

  LoginOdooState({
    this.username,
    this.password,
    this.message,
    this.requestStatus = RequestStatus.initial,
  });

  LoginOdooState copyWith({
    String? username,
    String? password,
    String? message,
    RequestStatus? requestStatus,
    bool? hasUnsyncedEmployees,
  }) {
    return LoginOdooState(
      username: username ?? this.username,
      password: password ?? this.password,
      message: message ?? this.message,
      requestStatus: requestStatus ?? RequestStatus.initial,
    );
  }
}
