import 'package:face_time_keeping/common/enums/request_status.dart';
import 'package:face_time_keeping/entities/session.dart';

class SessionState {
  final RequestStatus requestStatus;
  final List<Session> sessions;
  final Session? selectedSession;
  final SessionSummary? summary;
  final String? message;

  SessionState({
    this.requestStatus = RequestStatus.initial,
    this.sessions = const [],
    this.selectedSession,
    this.summary,
    this.message,
  });

  SessionState copyWith({
    RequestStatus? requestStatus,
    List<Session>? sessions,
    Session? selectedSession,
    SessionSummary? summary,
    String? message,
  }) {
    return SessionState(
      requestStatus: requestStatus ?? this.requestStatus,
      sessions: sessions ?? this.sessions,
      selectedSession: selectedSession ?? this.selectedSession,
      summary: summary ?? this.summary,
      message: message,
    );
  }
}
