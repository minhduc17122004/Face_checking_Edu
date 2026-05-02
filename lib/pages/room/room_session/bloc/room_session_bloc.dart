import 'package:face_time_keeping/common/api_client/data_state.dart';
import 'package:face_time_keeping/common/enums/session_attendance_mode.dart';
import 'package:face_time_keeping/common/enums/request_status.dart';
import 'package:face_time_keeping/common/utils/preset_checkin_policy.dart';
import 'package:face_time_keeping/data/remote/room_session_service.dart';
import 'package:face_time_keeping/data/remote/device_request_service.dart';
import 'package:face_time_keeping/data/local/local_service.dart';
import 'package:face_time_keeping/data/remote/session_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import 'package:face_time_keeping/entities/course.dart';
import 'package:face_time_keeping/entities/room_session.dart';
import 'package:face_time_keeping/entities/session.dart';

import 'room_session_state.dart';

@injectable
class RoomSessionBloc extends Cubit<RoomSessionState> {
  RoomSessionBloc(
    this._roomSessionService,
    this._deviceRequestService,
    this._localService,
    this._sessionService,
  ) : super(RoomSessionState());

  final RoomSessionService _roomSessionService;
  final DeviceRequestService _deviceRequestService;
  final LocalService _localService;
  final SessionService _sessionService;

  Future<void> loadRooms() async {
    emit(state.copyWith(requestStatus: RequestStatus.requesting));

    // 1. Get current device code
    final deviceCode = await _localService.getDeviceCode();

    // 2. Get approved rooms for this device from backend
    final requestResult = await _deviceRequestService.getMyRequests(deviceCode);
    final List<String> approvedRoomIds = [];
    bool isGlobal = false;

    if (requestResult.isSuccess) {
      final myRequests = requestResult.data ?? [];
      for (final r in myRequests) {
        if (r.isApproved) {
          if (r.roomId == null) {
            isGlobal = true;
          } else {
            approvedRoomIds.add(r.roomId!);
          }
        }
      }
    }

    // 3. Load all rooms
    final result = await _roomSessionService.getRooms();
    if (result.isSuccess) {
      var rooms = result.data ?? [];

      // 4. Apply filter if there are approved rooms
      if (isGlobal) {
        // Show all rooms (global permission)
      } else if (approvedRoomIds.isNotEmpty) {
        // Show only assigned rooms
        rooms = rooms.where((r) => approvedRoomIds.contains(r.id)).toList();
      } else {
        // No approved rooms -> Empty list
        rooms = [];
      }

      emit(state.copyWith(
        requestStatus: RequestStatus.success,
        rooms: rooms,
      ));
    } else {
      emit(state.copyWith(
        requestStatus: RequestStatus.failed,
        message: result.error ?? 'Failed to load rooms',
      ));
    }
  }

  Future<void> loadRoomSessions(
    String roomId, {
    DateTime? sessionDate,
  }) async {
    emit(state.copyWith(requestStatus: RequestStatus.requesting));

    // Fetch sessions and courses in parallel
    final results = await Future.wait([
      _roomSessionService.getRoomSessions(roomId, sessionDate: sessionDate),
      _roomSessionService.getRoomCourses(roomId),
    ]);

    final sessionResult = results[0] as DataState<List<RoomSession>>;
    final courseResult = results[1] as DataState<List<Course>>;

    if (sessionResult.isSuccess) {
      emit(state.copyWith(
        requestStatus: RequestStatus.success,
        sessions: sessionResult.data ?? [],
        courses:
            courseResult.isSuccess ? courseResult.data ?? [] : state.courses,
      ));
    } else {
      emit(state.copyWith(
        requestStatus: RequestStatus.failed,
        message: sessionResult.error ?? 'Failed to load sessions',
      ));
    }
  }

  void selectRoom(room) {
    emit(state.copyWith(selectedRoom: room));
  }

  Future<void> activateSession(String sessionId, String roomId,
      {DateTime? sessionDate}) async {
    emit(state.copyWith(requestStatus: RequestStatus.requesting));
    final result = await _roomSessionService.activateSession(sessionId);
    if (result.isSuccess) {
      // Reload sessions after activation
      await loadRoomSessions(roomId, sessionDate: sessionDate);
    } else {
      emit(state.copyWith(
        requestStatus: RequestStatus.failed,
        message: result.error ?? 'Failed to activate session',
      ));
    }
  }

  Future<void> closeSession(String sessionId, String roomId,
      {DateTime? sessionDate}) async {
    emit(state.copyWith(requestStatus: RequestStatus.requesting));
    final result = await _roomSessionService.closeSession(sessionId);
    if (result.isSuccess) {
      await loadRoomSessions(roomId, sessionDate: sessionDate);
    } else {
      emit(state.copyWith(
        requestStatus: RequestStatus.failed,
        message: result.error ?? 'Failed to close session',
      ));
    }
  }

  Future<void> loadActiveRoomSession(String roomId) async {
    emit(state.copyWith(
      requestStatus: RequestStatus.requesting,
      clearActiveSession: true,
      hasActiveSession: false,
    ));

    final activeResult = await _roomSessionService.getActiveRoomSession(roomId);

    if (!activeResult.isSuccess) {
      emit(state.copyWith(
        requestStatus: RequestStatus.failed,
        message: activeResult.error ?? 'Failed to load active session',
        hasActiveSession: true,
        clearActiveSession: true,
      ));
      return;
    }

    if (activeResult.data != null) {
      emit(state.copyWith(
        requestStatus: RequestStatus.success,
        activeSession: activeResult.data,
        hasActiveSession: true,
      ));
      return;
    }

    final eligibleResult =
        await _roomSessionService.getEligibleCheckinSession(roomId);
    if (eligibleResult.isSuccess) {
      final eligible = eligibleResult.data;
      if (eligible?.session != null) {
        await _emitEligibleSession(roomId, eligible!.session!);
        return;
      }

      emit(state.copyWith(
        requestStatus: RequestStatus.success,
        message: eligible?.message,
        hasActiveSession: true,
        clearActiveSession: true,
      ));
      return;
    }

    final now = DateTime.now();
    final sessionsResult = await _loadEarlyWindowSessions(roomId, now);

    if (!sessionsResult.isSuccess) {
      emit(state.copyWith(
        requestStatus: RequestStatus.failed,
        message: sessionsResult.error ?? 'Failed to load room sessions',
        hasActiveSession: true,
        clearActiveSession: true,
      ));
      return;
    }

    final sessions = [...(sessionsResult.data ?? <RoomSession>[])];
    sessions.sort((a, b) => a.startTime.compareTo(b.startTime));

    final ongoingSession = _findOngoingSession(sessions, now);
    if (ongoingSession != null) {
      final endText = _formatTime(roomSessionEndTime(ongoingSession));
      emit(state.copyWith(
        requestStatus: RequestStatus.success,
        message:
            'Phòng đang có học phần "${ongoingSession.courseName}" diễn ra đến $endText. Chưa thể điểm danh sớm cho học phần kế tiếp.',
        hasActiveSession: true,
        clearActiveSession: true,
      ));
      return;
    }

    final earlySession = _findEarlyPresetSession(sessions, now);
    if (earlySession != null) {
      final activateResult =
          await _roomSessionService.activateSession(earlySession.id);
      if (!activateResult.isSuccess) {
        emit(state.copyWith(
          requestStatus: RequestStatus.failed,
          message: activateResult.error ?? 'Failed to activate early session',
          hasActiveSession: true,
          clearActiveSession: true,
        ));
        return;
      }

      final refreshedActiveResult =
          await _roomSessionService.getActiveRoomSession(roomId);
      final activatedSession =
          refreshedActiveResult.isSuccess && refreshedActiveResult.data != null
              ? refreshedActiveResult.data
              : earlySession;

      emit(state.copyWith(
        requestStatus: RequestStatus.success,
        activeSession: activatedSession,
        hasActiveSession: true,
      ));
    } else {
      emit(state.copyWith(
        requestStatus: RequestStatus.success,
        hasActiveSession: true,
        clearActiveSession: true,
      ));
    }
  }

  Future<void> _emitEligibleSession(
    String roomId,
    RoomSession session,
  ) async {
    if (session.isScheduled) {
      final activateResult =
          await _roomSessionService.activateSession(session.id);
      if (!activateResult.isSuccess) {
        emit(state.copyWith(
          requestStatus: RequestStatus.failed,
          message: activateResult.error ?? 'Failed to activate early session',
          hasActiveSession: true,
          clearActiveSession: true,
        ));
        return;
      }
    }

    final refreshedActiveResult =
        await _roomSessionService.getActiveRoomSession(roomId);
    final activeSession =
        refreshedActiveResult.isSuccess && refreshedActiveResult.data != null
            ? refreshedActiveResult.data
            : session;

    emit(state.copyWith(
      requestStatus: RequestStatus.success,
      activeSession: activeSession,
      hasActiveSession: true,
    ));
  }

  RoomSession? _findOngoingSession(List<RoomSession> sessions, DateTime now) {
    for (final session in sessions) {
      if (isOngoingRoomSession(session, now: now)) {
        return session;
      }
    }
    return null;
  }

  RoomSession? _findEarlyPresetSession(
    List<RoomSession> sessions,
    DateTime now,
  ) {
    for (final session in sessions) {
      if (isPresetEarlyCheckInCandidate(session, now: now)) {
        return session;
      }
    }
    return null;
  }

  String _formatTime(DateTime value) {
    final local = value.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  Future<DataState<List<RoomSession>>> _loadEarlyWindowSessions(
    String roomId,
    DateTime now,
  ) async {
    final dates = <DateTime>[now];
    final earlyWindowEnd = now.add(presetEarlyCheckInWindow);
    if (!_isSameLocalDate(now, earlyWindowEnd)) {
      dates.add(earlyWindowEnd);
    }

    final sessions = <RoomSession>[];
    for (final date in dates) {
      final result =
          await _roomSessionService.getRoomSessions(roomId, sessionDate: date);
      if (!result.isSuccess) {
        final fallbackResult =
            await _loadRoomSessionsFromCourses(roomId, sessionDate: date);
        if (!fallbackResult.isSuccess) {
          return DataFailed<List<RoomSession>>(
            result.error ?? fallbackResult.error,
          );
        }
        sessions.addAll(fallbackResult.data ?? const <RoomSession>[]);
        continue;
      }
      sessions.addAll(result.data ?? const <RoomSession>[]);
    }

    return DataSuccess<List<RoomSession>>(_dedupeSessions(sessions));
  }

  Future<DataState<List<RoomSession>>> _loadRoomSessionsFromCourses(
    String roomId, {
    required DateTime sessionDate,
  }) async {
    final coursesResult = await _roomSessionService.getRoomCourses(roomId);
    if (!coursesResult.isSuccess) {
      return DataFailed<List<RoomSession>>(coursesResult.error);
    }

    final courses = coursesResult.data ?? const <Course>[];
    final sessions = <RoomSession>[];
    for (final course in courses) {
      final courseSessionsResult = await _sessionService.getSessions(
        courseId: course.id,
        date: sessionDate,
        limit: 100,
      );
      if (!courseSessionsResult.isSuccess) {
        return DataFailed<List<RoomSession>>(courseSessionsResult.error);
      }
      for (final session in courseSessionsResult.data ?? const <Session>[]) {
        sessions.add(_roomSessionFromSession(session, course));
      }
    }

    return DataSuccess<List<RoomSession>>(sessions);
  }

  RoomSession _roomSessionFromSession(Session session, Course course) {
    return RoomSession(
      id: session.id,
      courseId: session.courseId,
      courseName: session.courseName ?? course.courseName,
      courseCode: session.courseCode ?? course.courseCode,
      teacherName: session.teacherName ?? course.teacherName,
      sessionDate: session.sessionDate ?? session.startTime,
      startTime: session.startTime,
      endTime: session.endTime,
      status: session.status,
      mappedStatus: session.mappedStatus ?? session.status.value,
      attendanceMode: session.attendanceMode ??
          SessionAttendanceModeX.fromString(course.attendanceMode.value),
      checkinWindowStart: session.checkinWindowStart,
      checkinWindowEnd: session.checkinWindowEnd,
      attendanceCount: session.presentCount,
      totalEnrolled: session.enrolledCount,
      canOpen: session.canOpen,
      canClose: session.canClose,
    );
  }

  bool _isSameLocalDate(DateTime a, DateTime b) {
    final localA = a.toLocal();
    final localB = b.toLocal();
    return localA.year == localB.year &&
        localA.month == localB.month &&
        localA.day == localB.day;
  }

  List<RoomSession> _dedupeSessions(List<RoomSession> sessions) {
    final byId = <String, RoomSession>{};
    for (final session in sessions) {
      byId[session.id] = session;
    }
    return byId.values.toList();
  }

  void reset() {
    emit(RoomSessionState());
  }
}
