part of 'session_management_cubit.dart';

class SessionManagementState {
  final List<Session> sessions;
  final List<Session> scheduledSessions;
  final List<Session> activeSessions;
  final List<Session> closedSessions;
  final RequestStatus status;
  final String message;
  final DateTime? filterDate;

  const SessionManagementState({
    this.sessions = const [],
    this.scheduledSessions = const [],
    this.activeSessions = const [],
    this.closedSessions = const [],
    this.status = RequestStatus.initial,
    this.message = '',
    this.filterDate,
  });

  SessionManagementState copyWith({
    List<Session>? sessions,
    List<Session>? scheduledSessions,
    List<Session>? activeSessions,
    List<Session>? closedSessions,
    RequestStatus? status,
    String? message,
    DateTime? filterDate,
  }) {
    return SessionManagementState(
      sessions: sessions ?? this.sessions,
      scheduledSessions: scheduledSessions ?? this.scheduledSessions,
      activeSessions: activeSessions ?? this.activeSessions,
      closedSessions: closedSessions ?? this.closedSessions,
      status: status ?? this.status,
      message: message ?? this.message,
      filterDate: filterDate ?? this.filterDate,
    );
  }
}
