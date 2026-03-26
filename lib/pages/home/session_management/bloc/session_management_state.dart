part of 'session_management_cubit.dart';

class SessionManagementState {
  final List<Session> sessions;
  final RequestStatus status;
  final String message;
  final DateTime? filterDate;

  const SessionManagementState({
    this.sessions = const [],
    this.status = RequestStatus.initial,
    this.message = '',
    this.filterDate,
  });

  SessionManagementState copyWith({
    List<Session>? sessions,
    RequestStatus? status,
    String? message,
    DateTime? filterDate,
  }) {
    return SessionManagementState(
      sessions: sessions ?? this.sessions,
      status: status ?? this.status,
      message: message ?? this.message,
      filterDate: filterDate ?? this.filterDate,
    );
  }
}
