import '../../common/enums/request_status.dart';

enum BootstrapStatus {
  initial,
  authenticated,
  unauthenticated,
  domainError,
  offlineMode
}

class BootstrapState {
  final BootstrapStatus status;
  final RequestStatus requestStatus;
  final String? cachedDomain;
  final String? loginID;
  final String? password;
  const BootstrapState({
    this.status = BootstrapStatus.initial,
    this.requestStatus = RequestStatus.initial,
    this.cachedDomain,
    this.loginID,
    this.password,
  });

  BootstrapState copyWith({
    BootstrapStatus? status,
    RequestStatus? requestStatus,
    String? cachedDomain,
    String? loginID,
    String? password,
  }) {
    return BootstrapState(
      status: status ?? this.status,
      requestStatus: requestStatus ?? this.requestStatus,
      cachedDomain: cachedDomain ?? this.cachedDomain,
      loginID: loginID ?? this.loginID,
      password: password ?? this.password,
    );
  }
}
