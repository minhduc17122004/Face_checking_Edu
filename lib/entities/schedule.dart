import 'time_slot.dart';

class Schedule {
  final String id;
  final String courseId;
  final String courseName;
  final int dayOfWeek;
  final int timeSlotId;
  final int? endTimeSlotId;
  final TimeSlot? timeSlot;
  final TimeSlot? endTimeSlot;
  final DateTime createdAt;

  const Schedule({
    required this.id,
    required this.courseId,
    required this.courseName,
    required this.dayOfWeek,
    required this.timeSlotId,
    this.endTimeSlotId,
    this.timeSlot,
    this.endTimeSlot,
    required this.createdAt,
  });

  factory Schedule.fromJson(Map<String, dynamic> json) {
    TimeSlot? ts;
    if (json['time_slot'] != null) {
      ts = TimeSlot.fromJson(json['time_slot'] as Map<String, dynamic>);
    }
    TimeSlot? endTs;
    if (json['end_time_slot'] != null) {
      endTs = TimeSlot.fromJson(json['end_time_slot'] as Map<String, dynamic>);
    }
    return Schedule(
      id: json['id'] as String,
      courseId: json['course_id'] as String,
      courseName: json['course_name'] as String? ?? 'Unknown',
      dayOfWeek: json['day_of_week'] as int,
      timeSlotId: json['time_slot_id'] as int,
      endTimeSlotId: json['end_time_slot_id'] as int?,
      timeSlot: ts,
      endTimeSlot: endTs,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'course_id': courseId,
      'day_of_week': dayOfWeek,
      'time_slot_id': timeSlotId,
      'end_time_slot_id': endTimeSlotId,
    };
  }

  String get dayName {
    const days = [
      'Thứ 2',
      'Thứ 3',
      'Thứ 4',
      'Thứ 5',
      'Thứ 6',
      'Thứ 7',
      'Chủ nhật'
    ];
    if (dayOfWeek < 1 || dayOfWeek > 7) return '';
    return days[dayOfWeek - 1];
  }

  int get resolvedEndTimeSlotId => endTimeSlotId ?? timeSlotId;

  String get slotLabel {
    final startPeriod = timeSlot?.periodNumber;
    final endPeriod = endTimeSlot?.periodNumber ?? startPeriod;
    if (startPeriod == null) return 'Tiết ?';
    if (startPeriod == endPeriod) return 'Tiết $startPeriod';
    return 'Tiết $startPeriod-$endPeriod';
  }

  String get displayTimeRange {
    final start = timeSlot?.startTime;
    final end = endTimeSlot?.endTime ?? timeSlot?.endTime;
    if (start == null || end == null) return slotLabel;
    return '$start - $end';
  }

  @override
  String toString() =>
      'Schedule(id: $id, courseId: $courseId, day: $dayName, slot: $timeSlotId-$resolvedEndTimeSlotId)';
}
