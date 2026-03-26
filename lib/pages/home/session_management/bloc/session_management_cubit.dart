import 'package:bloc/bloc.dart';
import 'package:face_time_keeping/common/api_client/data_state.dart';
import 'package:face_time_keeping/common/enums/request_status.dart';
import 'package:face_time_keeping/common/utils/log_util.dart';
import 'package:face_time_keeping/data/remote/session_service.dart';
import 'package:face_time_keeping/entities/session.dart';
import 'package:injectable/injectable.dart';

part 'session_management_state.dart';

@injectable
class SessionManagementCubit extends Cubit<SessionManagementState> {
  SessionManagementCubit(this._sessionService)
      : super(const SessionManagementState());

  final SessionService _sessionService;

  Future<void> loadTeacherSessions({DateTime? date}) async {
    try {
      emit(state.copyWith(status: RequestStatus.requesting));

      final targetDate = date ?? DateTime.now();
      await _sessionService.generateDailySessions(targetDate);

      final result = await _sessionService.getTeacherSessions(date: date);
      if (result.isSuccess) {
        emit(state.copyWith(
          status: RequestStatus.success,
          sessions: result.data ?? [],
        ));
      } else {
        emit(state.copyWith(
          status: RequestStatus.failed,
          message: result.error ?? 'Failed to load sessions',
        ));
      }
    } catch (e) {
      await pushLog('Error in loadTeacherSessions: $e');
      emit(state.copyWith(
        status: RequestStatus.failed,
        message: e.toString(),
      ));
    }
  }

  Future<void> activateSession(String id) async {
    try {
      emit(state.copyWith(status: RequestStatus.requesting));
      final result = await _sessionService.activateSession(id);
      if (result.isSuccess) {
        await loadTeacherSessions();
      } else {
        emit(state.copyWith(
          status: RequestStatus.failed,
          message: result.error ?? 'Failed to open session',
        ));
      }
    } catch (e) {
      await pushLog('Error in activateSession: $e');
      emit(state.copyWith(
        status: RequestStatus.failed,
        message: e.toString(),
      ));
    }
  }

  Future<void> closeSession(String id) async {
    try {
      emit(state.copyWith(status: RequestStatus.requesting));
      final result = await _sessionService.closeSession(id);
      if (result.isSuccess) {
        await loadTeacherSessions();
      } else {
        emit(state.copyWith(
          status: RequestStatus.failed,
          message: result.error ?? 'Failed to close session',
        ));
      }
    } catch (e) {
      await pushLog('Error in closeSession: $e');
      emit(state.copyWith(
        status: RequestStatus.failed,
        message: e.toString(),
      ));
    }
  }
}
