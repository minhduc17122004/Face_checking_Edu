class TimeSlot {
  final int id;
  final int periodNumber;
  final String startTime;
  final String endTime;
  final DateTime? createdAt;

  const TimeSlot({
    required this.id,
    required this.periodNumber,
    required this.startTime,
    required this.endTime,
    this.createdAt,
  });

  factory TimeSlot.fromJson(Map<String, dynamic> json) {
    return TimeSlot(
      id: json['id'] as int,
      periodNumber: json['period_number'] as int,
      startTime: _formatTime(json['start_time']),
      endTime: _formatTime(json['end_time']),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  static String _formatTime(dynamic timeValue) {
    if (timeValue == null) return '--:--';
    if (timeValue is String) {
      if (timeValue.contains('T')) {
        final parts = timeValue.split('T');
        if (parts.length > 1) {
          return parts[1].substring(0, 5);
        }
      }
      return timeValue.substring(0, 5);
    }
    return '--:--';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'period_number': periodNumber,
      'start_time': startTime,
      'end_time': endTime,
    };
  }

  TimeSlot copyWith({
    int? id,
    int? periodNumber,
    String? startTime,
    String? endTime,
    DateTime? createdAt,
  }) {
    return TimeSlot(
      id: id ?? this.id,
      periodNumber: periodNumber ?? this.periodNumber,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  String get displayName => 'Tiết $periodNumber';
  String get timeRange => '$startTime - $endTime';
  String get displayTime => '$startTime - $endTime';

  @override
  String toString() =>
      'TimeSlot(id: $id, period: $periodNumber, time: $timeRange)';
}
