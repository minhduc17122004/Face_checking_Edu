import 'package:face_time_keeping/common/enums/request_status.dart';
import 'package:face_time_keeping/entities/schedule.dart';
import 'package:face_time_keeping/entities/time_slot.dart';

class ScheduleState {
  final RequestStatus requestStatus;
  final List<Schedule> schedules;
  final List<TimeSlot> timeSlots;
  final String? message;

  ScheduleState({
    this.requestStatus = RequestStatus.initial,
    this.schedules = const [],
    this.timeSlots = const [],
    this.message,
  });

  ScheduleState copyWith({
    RequestStatus? requestStatus,
    List<Schedule>? schedules,
    List<TimeSlot>? timeSlots,
    String? message,
  }) {
    return ScheduleState(
      requestStatus: requestStatus ?? this.requestStatus,
      schedules: schedules ?? this.schedules,
      timeSlots: timeSlots ?? this.timeSlots,
      message: message,
    );
  }
}
