import 'package:face_time_keeping/common/api_client/data_state.dart';
import 'package:face_time_keeping/common/enums/request_status.dart';
import 'package:face_time_keeping/data/remote/session_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import 'session_state.dart';

@injectable
class SessionBloc extends Cubit<SessionState> {
  SessionBloc(this._sessionService) : super(SessionState());

  final SessionService _sessionService;

  Future<void> loadSessions({
    String? courseId,
    DateTime? date,
    String? status,
  }) async {
    emit(state.copyWith(requestStatus: RequestStatus.requesting));
    final result = await _sessionService.getSessions(
      courseId: courseId,
      date: date,
      status: status,
    );
    if (result.isSuccess) {
      emit(state.copyWith(
        requestStatus: RequestStatus.success,
        sessions: result.data ?? [],
      ));
    } else {
      emit(state.copyWith(
        requestStatus: RequestStatus.failed,
        message: result.error ?? 'Failed to load sessions',
      ));
    }
  }

  Future<void> createSession({
    required String courseId,
    String? scheduleId,
    required DateTime sessionDate,
    required DateTime startTime,
    DateTime? endTime,
    DateTime? checkinWindowStart,
    DateTime? checkinWindowEnd,
  }) async {
    emit(state.copyWith(requestStatus: RequestStatus.requesting));
    final result = await _sessionService.createSession(
      courseId: courseId,
      scheduleId: scheduleId,
      sessionDate: sessionDate,
      startTime: startTime,
      endTime: endTime,
      checkinWindowStart: checkinWindowStart,
      checkinWindowEnd: checkinWindowEnd,
    );
    if (result.isSuccess) {
      emit(state.copyWith(
        requestStatus: RequestStatus.success,
        selectedSession: result.data,
      ));
    } else {
      emit(state.copyWith(
        requestStatus: RequestStatus.failed,
        message: result.error ?? 'Failed to create session',
      ));
    }
  }

  Future<void> activateSession(String id) async {
    emit(state.copyWith(requestStatus: RequestStatus.requesting));
    final result = await _sessionService.activateSession(id);
    if (result.isSuccess) {
      emit(state.copyWith(
        requestStatus: RequestStatus.success,
        selectedSession: result.data,
      ));
    } else {
      emit(state.copyWith(
        requestStatus: RequestStatus.failed,
        message: result.error ?? 'Failed to activate session',
      ));
    }
  }

  Future<void> closeSession(String id) async {
    emit(state.copyWith(requestStatus: RequestStatus.requesting));
    final result = await _sessionService.closeSession(id);
    if (result.isSuccess) {
      emit(state.copyWith(
        requestStatus: RequestStatus.success,
        selectedSession: result.data,
      ));
    } else {
      emit(state.copyWith(
        requestStatus: RequestStatus.failed,
        message: result.error ?? 'Failed to close session',
      ));
    }
  }

  Future<void> loadSessionSummary(String id) async {
    emit(state.copyWith(requestStatus: RequestStatus.requesting));
    final result = await _sessionService.getSessionSummary(id);
    if (result.isSuccess) {
      emit(state.copyWith(
        requestStatus: RequestStatus.success,
        summary: result.data,
      ));
    } else {
      emit(state.copyWith(
        requestStatus: RequestStatus.failed,
        message: result.error ?? 'Failed to load session summary',
      ));
    }
  }

  Future<void> generateDailySessions(DateTime date) async {
    emit(state.copyWith(requestStatus: RequestStatus.requesting));
    final result = await _sessionService.generateDailySessions(date);
    if (result.isSuccess) {
      final data = result.data;
      if (data != null) {
        emit(state.copyWith(
          requestStatus: RequestStatus.success,
          message: 'Đã tạo ${data['created_count'] ?? 0} phiên điểm danh',
        ));
      } else {
        emit(state.copyWith(requestStatus: RequestStatus.success));
      }
    } else {
      emit(state.copyWith(
        requestStatus: RequestStatus.failed,
        message: result.error ?? 'Failed to generate sessions',
      ));
    }
  }

  Future<void> deleteSession(String id) async {
    emit(state.copyWith(requestStatus: RequestStatus.requesting));
    final result = await _sessionService.deleteSession(id);
    if (result.isSuccess) {
      emit(state.copyWith(requestStatus: RequestStatus.success));
      await loadSessions();
    } else {
      emit(state.copyWith(
        requestStatus: RequestStatus.failed,
        message: result.error ?? 'Failed to delete session',
      ));
    }
  }
}
