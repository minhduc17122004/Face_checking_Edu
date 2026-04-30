import 'package:bloc/bloc.dart';
import 'package:face_time_keeping/common/api_client/data_state.dart';
import 'package:face_time_keeping/common/enums/request_status.dart';
import 'package:face_time_keeping/common/utils/log_util.dart';
import 'package:face_time_keeping/data/local/local_service.dart';
import 'package:face_time_keeping/data/remote/session_service.dart';
import 'package:face_time_keeping/di/injection.dart';
import 'package:face_time_keeping/entities/session.dart';
import 'package:injectable/injectable.dart';

part 'session_management_state.dart';

@injectable
class SessionManagementCubit extends Cubit<SessionManagementState> {
  SessionManagementCubit(this._sessionService)
      : super(const SessionManagementState());

  final SessionService _sessionService;

  bool get _isAdmin {
    try {
      final localService = getIt<LocalService>();
      return localService.getUserRole().toLowerCase() == 'admin';
    } catch (_) {
      return false;
    }
  }

  Future<void> loadTeacherSessions({DateTime? date}) async {
    try {
      emit(state.copyWith(status: RequestStatus.requesting));

      final target = date ?? DateTime.now();

      // Tính đầu tuần (Monday) và cuối tuần (Sunday)
      final weekday = target.weekday; // 1=Mon, 7=Sun
      final monday = target.subtract(Duration(days: weekday - 1));
      final sunday = monday.add(const Duration(days: 6));

      // Generate phiên cho từng ngày trong tuần (idempotent)
      for (var i = 0; i < 7; i++) {
        await _sessionService
            .generateDailySessions(monday.add(Duration(days: i)));
      }

      // Admin dùng endpoint riêng để lấy tất cả phiên
      final DataState<List<Session>> result;
      if (_isAdmin) {
        result = await _sessionService.getAdminSessions(
          dateFrom: monday,
          dateTo: sunday,
        );
      } else {
        result = await _sessionService.getTeacherSessions(
          dateFrom: monday,
          dateTo: sunday,
        );
      }

      if (result.isSuccess) {
        final sessions = result.data ?? [];

        // Phân loại DỰA TRÊN mappedStatus do backend tính (source of truth).
        // mappedStatus: OPEN | CLOSED | CAN_OPEN | NOT_OPEN
        final scheduledSessions = sessions.where((s) {
          final ms = (s.mappedStatus ?? '').toUpperCase();
          return ms == 'NOT_OPEN' || ms == 'CAN_OPEN' || ms == 'UPCOMING';
        }).toList()
          ..sort((a, b) => a.startTime.compareTo(b.startTime));

        final activeSessions = sessions
            .where((s) => (s.mappedStatus ?? '').toUpperCase() == 'OPEN')
            .toList()
          ..sort((a, b) => a.startTime.compareTo(b.startTime));

        final closedSessions = sessions
            .where((s) => (s.mappedStatus ?? '').toUpperCase() == 'CLOSED')
            .toList()
          ..sort((a, b) =>
              (b.endTime ?? b.startTime).compareTo(a.endTime ?? a.startTime));

        emit(state.copyWith(
          status: RequestStatus.success,
          sessions: sessions,
          scheduledSessions: scheduledSessions,
          activeSessions: activeSessions,
          closedSessions: closedSessions,
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
        await loadTeacherSessions(date: DateTime.now());
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
        await loadTeacherSessions(date: DateTime.now());
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
