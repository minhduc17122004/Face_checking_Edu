class TimeSlot {
  final int id;
  final int periodNumber;
  final String startTime;
  final String endTime;

  const TimeSlot({
    required this.id,
    required this.periodNumber,
    required this.startTime,
    required this.endTime,
  });

  factory TimeSlot.fromJson(Map<String, dynamic> json) {
    return TimeSlot(
      id: json['id'] as int,
      periodNumber: json['period_number'] as int,
      startTime: _parseTime(json['start_time']),
      endTime: _parseTime(json['end_time']),
    );
  }

  static String _parseTime(dynamic value) {
    if (value == null) return '';
    if (value is String) {
      if (value.contains('T')) {
        final parts = value.split('T');
        return parts.length > 1 ? parts[1].substring(0, 5) : value;
      }
      return value;
    }
    return value.toString();
  }

  String get slotName => 'Tiết $periodNumber';

  String get displayTime => '$startTime - $endTime';

  @override
  String toString() =>
      'TimeSlot(id: $id, period: $periodNumber, time: $displayTime)';
}

class TimeSlotConfig {
  static const List<TimeSlot> defaultSlots = [
    TimeSlot(id: 1, periodNumber: 1, startTime: '07:00', endTime: '07:45'),
    TimeSlot(id: 2, periodNumber: 2, startTime: '07:50', endTime: '08:35'),
    TimeSlot(id: 3, periodNumber: 3, startTime: '08:40', endTime: '09:25'),
    TimeSlot(id: 4, periodNumber: 4, startTime: '09:30', endTime: '10:15'),
    TimeSlot(id: 5, periodNumber: 5, startTime: '10:20', endTime: '11:05'),
    TimeSlot(id: 6, periodNumber: 6, startTime: '13:00', endTime: '13:45'),
    TimeSlot(id: 7, periodNumber: 7, startTime: '13:50', endTime: '14:35'),
    TimeSlot(id: 8, periodNumber: 8, startTime: '14:40', endTime: '15:25'),
    TimeSlot(id: 9, periodNumber: 9, startTime: '15:30', endTime: '16:15'),
    TimeSlot(id: 10, periodNumber: 10, startTime: '16:20', endTime: '17:05'),
  ];
}
