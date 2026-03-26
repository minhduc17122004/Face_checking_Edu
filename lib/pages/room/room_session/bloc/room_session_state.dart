import 'package:face_time_keeping/common/enums/request_status.dart';
import 'package:face_time_keeping/entities/room.dart';
import 'package:face_time_keeping/entities/room_session.dart';
import 'package:face_time_keeping/entities/course.dart';

class RoomSessionState {
  final RequestStatus requestStatus;
  final List<Room> rooms;
  final List<RoomSession> sessions;
  final List<Course> courses;
  final Room? selectedRoom;
  final String? message;

  /// The single active session returned by GET /rooms/{id}/active-session.
  /// Null  → no active session in the room right now.
  /// The [_hasActiveSession] flag distinguishes between:
  ///   - "field not yet loaded" (false) vs.
  ///   - "loaded and confirmed null" (true, activeSession == null).
  final RoomSession? activeSession;
  final bool hasActiveSession;

  RoomSessionState({
    this.requestStatus = RequestStatus.initial,
    this.rooms = const [],
    this.sessions = const [],
    this.courses = const [],
    this.selectedRoom,
    this.message,
    this.activeSession,
    this.hasActiveSession = false,
  });

  RoomSessionState copyWith({
    RequestStatus? requestStatus,
    List<Room>? rooms,
    List<RoomSession>? sessions,
    List<Course>? courses,
    Room? selectedRoom,
    String? message,
    RoomSession? activeSession,
    bool? hasActiveSession,
    bool clearActiveSession = false,
  }) {
    return RoomSessionState(
      requestStatus: requestStatus ?? this.requestStatus,
      rooms: rooms ?? this.rooms,
      sessions: sessions ?? this.sessions,
      courses: courses ?? this.courses,
      selectedRoom: selectedRoom ?? this.selectedRoom,
      message: message,
      activeSession: clearActiveSession ? null : (activeSession ?? this.activeSession),
      hasActiveSession: hasActiveSession ?? (clearActiveSession ? true : this.hasActiveSession),
    );
  }

  // ── Derived lists (used by RoomSessionPage tab view) ─────────────────────
  List<RoomSession> get activeSessions =>
      sessions.where((s) => s.isActive).toList();

  List<RoomSession> get scheduledSessions =>
      sessions.where((s) => s.isScheduled).toList();

  List<RoomSession> get closedSessions =>
      sessions.where((s) => s.isClosed).toList();
}
