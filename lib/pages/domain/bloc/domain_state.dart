import 'package:equatable/equatable.dart';
import '../../../common/enums/request_status.dart';

class DomainState extends Equatable {
  final String? domain;
  final String? cachedDomain;
  final List<String> dbNames;

  final RequestStatus requestStatus;
  final bool? autoLogin;
  final String? message;

  const DomainState({
    this.domain,
    this.cachedDomain,
    this.dbNames = const [],
    this.requestStatus = RequestStatus.initial,
    this.autoLogin = false,
    this.message,
  });

  @override
  List<Object?> get props => [
        domain,
        cachedDomain,
        dbNames,
        requestStatus,
        autoLogin,
        message,
      ];

  DomainState copyWith({
    String? domain,
    String? cachedDomain,
    List<String>? dbNames,
    RequestStatus? requestStatus,
    bool? autoLogin,
    String? message,
  }) {
    return DomainState(
      domain: domain ?? this.domain,
      cachedDomain: cachedDomain ?? this.cachedDomain,
      dbNames: dbNames ?? this.dbNames,
      requestStatus: requestStatus ?? RequestStatus.initial,
      autoLogin: autoLogin ?? this.autoLogin,
      message: message ?? this.message,
    );
  }
}
