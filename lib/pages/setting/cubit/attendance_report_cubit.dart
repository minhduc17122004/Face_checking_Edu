import 'package:bloc/bloc.dart';
import 'package:face_time_keeping/common/enums/request_status.dart';
import 'package:face_time_keeping/common/event/event_bus_event.dart';
import 'package:face_time_keeping/common/event/event_bus_mixin.dart';
import 'package:face_time_keeping/common/utils/log_util.dart';

import 'package:face_time_keeping/data/local/local_service.dart';
import 'package:face_time_keeping/entities/check_in_out.dart';
import 'package:injectable/injectable.dart';

part 'attendance_report_state.dart';

@singleton
class AttendanceReportCubit extends Cubit<AttendanceReportState>
    with EventBusMixin {
  AttendanceReportCubit(this._localService)
      : super(const AttendanceReportState()) {
    listenEvent<SyncDataEvent>((e) => _refreshData());
  }

  final LocalService _localService;

  Future<void> _refreshData() async {
    try {
      if (!isClosed) {
        emit(state.copyWith(status: RequestStatus.requesting));
      }

      await _localService.refreshCheckInOutBox();
      if (!isClosed) {
        await loadAttendanceReport();
      }
    } catch (e) {
      await pushLog('Error in _refreshData: $e');
      if (!isClosed) {
        emit(state.copyWith(
            status: RequestStatus.failed, message: e.toString()));
      }
    }
  }

  Future<void> loadAttendanceReport() async {
    try {
      final filterDate = DateTime.now();

      emit(state.copyWith(
          status: RequestStatus.requesting, filterDate: filterDate));
      final checkInOuts = await _localService.getCheckInOutByDate(filterDate);
      emit(state.copyWith(
          checkInOuts: checkInOuts, status: RequestStatus.success));
    } catch (e) {
      await pushLog('Error in loadAttendanceReport: $e');
      emit(state.copyWith(status: RequestStatus.failed, message: e.toString()));
    }
  }

  Future<void> filterCheckInOuts(DateTime date) async {
    try {
      emit(state.copyWith(status: RequestStatus.requesting));
      final checkInOuts = await _localService.getCheckInOutByDate(date);
      emit(state.copyWith(
          checkInOuts: checkInOuts,
          status: RequestStatus.success,
          filterDate: date));
    } catch (e) {
      await pushLog('Error in filterCheckInOuts: $e');
      emit(state.copyWith(status: RequestStatus.failed, message: e.toString()));
    }
  }
}
