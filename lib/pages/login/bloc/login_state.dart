import 'package:face_time_keeping/common/enums/request_status.dart';

class LoginState {
  String? username;
  String? password;
  String? message;
  RequestStatus requestStatus;

  LoginState({
    this.username,
    this.password,
    this.message,
    this.requestStatus = RequestStatus.initial,
  });

  LoginState copyWith({
    String? username,
    String? password,
    String? message,
    RequestStatus? requestStatus,
    bool? hasUnsyncedEmployees,
  }) {
    return LoginState(
      username: username ?? this.username,
      password: password ?? this.password,
      message: message ?? this.message,
      requestStatus: requestStatus ?? RequestStatus.initial,
    );
  }
}
