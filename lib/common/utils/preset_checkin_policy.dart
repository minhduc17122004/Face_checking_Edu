import 'package:face_time_keeping/common/enums/session_attendance_mode.dart';
import 'package:face_time_keeping/entities/room_session.dart';

const presetEarlyCheckInWindow = Duration(minutes: 10);

bool isWithinPresetEarlyCheckInWindow(
  RoomSession session, {
  DateTime? now,
}) {
  if (session.attendanceMode != SessionAttendanceMode.preset) {
    return false;
  }
  final localNow = (now ?? DateTime.now()).toLocal();
  final start = session.startTime.toLocal();
  final earlyStart = start.subtract(presetEarlyCheckInWindow);
  return !localNow.isBefore(earlyStart) && localNow.isBefore(start);
}

bool isPresetEarlyCheckInCandidate(
  RoomSession session, {
  DateTime? now,
}) {
  return session.isScheduled &&
      isWithinPresetEarlyCheckInWindow(session, now: now);
}

bool isOngoingRoomSession(
  RoomSession session, {
  DateTime? now,
}) {
  if (!session.isActive) {
    return false;
  }
  final localNow = (now ?? DateTime.now()).toLocal();
  final start = session.startTime.toLocal();
  final end = roomSessionEndTime(session);
  return !localNow.isBefore(start) && localNow.isBefore(end);
}

DateTime roomSessionEndTime(RoomSession session) {
  return (session.endTime ?? session.startTime.add(const Duration(minutes: 45)))
      .toLocal();
}
