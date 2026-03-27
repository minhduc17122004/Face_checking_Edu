import 'package:face_time_keeping/common/api_client/data_state.dart';
import 'package:face_time_keeping/common/enums/request_status.dart';
import 'package:face_time_keeping/common/event/event_bus_event.dart';
import 'package:face_time_keeping/common/event/event_bus_mixin.dart';
import 'package:face_time_keeping/data/remote/attendance_history_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

/// State for the attendance history page.
class AttendanceHistoryState {
  final RequestStatus requestStatus;
  final List<AttendanceHistoryItem> items;
  final String? message;

  const AttendanceHistoryState({
    this.requestStatus = RequestStatus.initial,
    this.items = const [],
    this.message,
  });

  AttendanceHistoryState copyWith({
    RequestStatus? requestStatus,
    List<AttendanceHistoryItem>? items,
    String? message,
  }) {
    return AttendanceHistoryState(
      requestStatus: requestStatus ?? this.requestStatus,
      items: items ?? this.items,
      message: message ?? this.message,
    );
  }
}

@injectable
class AttendanceHistoryBloc extends Cubit<AttendanceHistoryState>
    with EventBusMixin {
  AttendanceHistoryBloc(this._historyService)
      : super(const AttendanceHistoryState()) {
    // Auto-refresh when a manual EDU sync completes
    listenEvent<EduSyncCompleteEvent>((e) {
      if (!isClosed && e.succeeded > 0) {
        loadHistory();
      }
    });
  }

  final AttendanceHistoryService _historyService;

  Future<void> loadHistory({String? courseId}) async {
    emit(state.copyWith(requestStatus: RequestStatus.requesting));
    final result = await _historyService.getHistory(courseId: courseId);
    if (result.isSuccess) {
      emit(state.copyWith(
        requestStatus: RequestStatus.success,
        items: result.data ?? [],
      ));
    } else {
      emit(state.copyWith(
        requestStatus: RequestStatus.failed,
        message: result.error ?? 'Không thể tải lịch sử điểm danh',
      ));
    }
  }

  void reset() {
    emit(const AttendanceHistoryState());
  }
}
