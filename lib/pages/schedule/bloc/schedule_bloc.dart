import 'package:face_time_keeping/common/api_client/data_state.dart';
import 'package:face_time_keeping/common/enums/request_status.dart';
import 'package:face_time_keeping/data/remote/schedule_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import 'schedule_state.dart';

@injectable
class ScheduleBloc extends Cubit<ScheduleState> {
  ScheduleBloc(this._scheduleService) : super(ScheduleState());

  final ScheduleService _scheduleService;

  Future<void> loadSchedules({
    String? courseId,
    int? dayOfWeek,
  }) async {
    emit(state.copyWith(requestStatus: RequestStatus.requesting));
    final result = await _scheduleService.getSchedules(
      courseId: courseId,
      dayOfWeek: dayOfWeek,
    );
    if (result.isSuccess) {
      emit(state.copyWith(
        requestStatus: RequestStatus.success,
        schedules: result.data ?? [],
      ));
    } else {
      emit(state.copyWith(
        requestStatus: RequestStatus.failed,
        message: result.error ?? 'Failed to load schedules',
      ));
    }
  }

  Future<void> loadTimeSlots() async {
    final result = await _scheduleService.getTimeSlots();
    if (result.isSuccess && result.data != null) {
      emit(state.copyWith(timeSlots: result.data!));
    }
  }

  Future<void> createSchedule({
    required String courseId,
    required int dayOfWeek,
    required int timeSlotId,
  }) async {
    emit(state.copyWith(requestStatus: RequestStatus.requesting));
    final result = await _scheduleService.createSchedule(
      courseId: courseId,
      dayOfWeek: dayOfWeek,
      timeSlotId: timeSlotId,
    );
    if (result.isSuccess) {
      emit(state.copyWith(requestStatus: RequestStatus.success));
      await loadSchedules(courseId: courseId);
    } else {
      emit(state.copyWith(
        requestStatus: RequestStatus.failed,
        message: result.error ?? 'Failed to create schedule',
      ));
    }
  }

  Future<void> updateSchedule({
    required String id,
    required String courseId,
    int? dayOfWeek,
    int? timeSlotId,
  }) async {
    emit(state.copyWith(requestStatus: RequestStatus.requesting));
    final result = await _scheduleService.updateSchedule(
      id: id,
      dayOfWeek: dayOfWeek,
      timeSlotId: timeSlotId,
    );
    if (result.isSuccess) {
      emit(state.copyWith(requestStatus: RequestStatus.success));
      await loadSchedules(courseId: courseId);
    } else {
      emit(state.copyWith(
        requestStatus: RequestStatus.failed,
        message: result.error ?? 'Failed to update schedule',
      ));
    }
  }

  Future<void> deleteSchedule({
    required String id,
    required String courseId,
  }) async {
    emit(state.copyWith(requestStatus: RequestStatus.requesting));
    final result = await _scheduleService.deleteSchedule(id);
    if (result.isSuccess) {
      emit(state.copyWith(requestStatus: RequestStatus.success));
      await loadSchedules(courseId: courseId);
    } else {
      emit(state.copyWith(
        requestStatus: RequestStatus.failed,
        message: result.error ?? 'Failed to delete schedule',
      ));
    }
  }
}
