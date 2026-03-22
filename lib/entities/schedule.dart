import 'time_slot.dart';

class Schedule {
  final String id;
  final String courseId;
  final int dayOfWeek;
  final int timeSlotId;
  final TimeSlot? timeSlot;
  final DateTime createdAt;

  const Schedule({
    required this.id,
    required this.courseId,
    required this.dayOfWeek,
    required this.timeSlotId,
    this.timeSlot,
    required this.createdAt,
  });

  factory Schedule.fromJson(Map<String, dynamic> json) {
    TimeSlot? ts;
    if (json['time_slot'] != null) {
      ts = TimeSlot.fromJson(json['time_slot'] as Map<String, dynamic>);
    }
    return Schedule(
      id: json['id'] as String,
      courseId: json['course_id'] as String,
      dayOfWeek: json['day_of_week'] as int,
      timeSlotId: json['time_slot_id'] as int,
      timeSlot: ts,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'course_id': courseId,
      'day_of_week': dayOfWeek,
      'time_slot_id': timeSlotId,
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

  @override
  String toString() =>
      'Schedule(id: $id, courseId: $courseId, day: $dayName, slot: $timeSlotId)';
}
