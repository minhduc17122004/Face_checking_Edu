import 'package:face_time_keeping/common/api_client/data_state.dart';
import 'package:face_time_keeping/common/enums/request_status.dart';
import 'package:face_time_keeping/data/remote/room_session_service.dart';
import 'package:face_time_keeping/data/remote/device_request_service.dart';
import 'package:face_time_keeping/data/local/local_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import 'package:face_time_keeping/entities/course.dart';
import 'package:face_time_keeping/entities/room_session.dart';

import 'room_session_state.dart';

@injectable
class RoomSessionBloc extends Cubit<RoomSessionState> {
  RoomSessionBloc(
    this._roomSessionService,
    this._deviceRequestService,
    this._localService,
  ) : super(RoomSessionState());

  final RoomSessionService _roomSessionService;
  final DeviceRequestService _deviceRequestService;
  final LocalService _localService;

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

    final result = await _roomSessionService.getActiveRoomSession(roomId);

    if (result.isSuccess) {
      emit(state.copyWith(
        requestStatus: RequestStatus.success,
        activeSession: result.data,
        hasActiveSession: true,
        clearActiveSession: result.data == null,
      ));
    } else {
      emit(state.copyWith(
        requestStatus: RequestStatus.failed,
        message: result.error ?? 'Failed to load active session',
        hasActiveSession: true,
        clearActiveSession: true,
      ));
    }
  }

  void reset() {
    emit(RoomSessionState());
  }
}
