import 'package:face_time_keeping/common/api_client/data_state.dart';
import 'package:face_time_keeping/common/enums/request_status.dart';
import 'package:face_time_keeping/data/remote/attendance_checkin_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import 'attendance_checkin_state.dart';

@injectable
class AttendanceCheckinBloc extends Cubit<AttendanceCheckinState> {
  AttendanceCheckinBloc(this._checkinService) : super(AttendanceCheckinState());

  final AttendanceCheckinService _checkinService;

  Future<void> loadSessionCheckins(String sessionId) async {
    emit(state.copyWith(requestStatus: RequestStatus.requesting));
    final result = await _checkinService.getSessionCheckins(sessionId);
    if (result.isSuccess) {
      emit(state.copyWith(
        requestStatus: RequestStatus.success,
        records: result.data ?? [],
      ));
    } else {
      emit(state.copyWith(
        requestStatus: RequestStatus.failed,
        message: result.error ?? 'Failed to load check-ins',
      ));
    }
  }

  Future<void> loadSessionSummary(String sessionId) async {
    final result = await _checkinService.getSessionSummary(sessionId);
    if (result.isSuccess) {
      emit(state.copyWith(summary: result.data));
    }
  }

  Future<void> manualCheckin({
    required String sessionId,
    required int studentId,
    DateTime? checkinTime,
    String status = 'present',
    String? deviceId,
  }) async {
    emit(state.copyWith(requestStatus: RequestStatus.requesting));
    final result = await _checkinService.manualCheckin(
      sessionId: sessionId,
      studentId: studentId,
      checkinTime: checkinTime,
      status: status,
      deviceId: deviceId,
    );
    if (result.isSuccess) {
      emit(state.copyWith(
        requestStatus: RequestStatus.success,
        lastCheckin: result.data,
      ));
      await loadSessionCheckins(sessionId);
      await loadSessionSummary(sessionId);
    } else {
      emit(state.copyWith(
        requestStatus: RequestStatus.failed,
        message: result.error ?? 'Check-in failed',
      ));
    }
  }

  bool hasRecordForStudent(int studentId) {
    return state.records.any((r) => r.studentId == studentId);
  }

  void reset() {
    emit(AttendanceCheckinState());
  }
}
