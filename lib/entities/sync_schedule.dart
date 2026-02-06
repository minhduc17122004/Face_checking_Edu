class SyncSchedule {
  final String time; // "08:00"
  final int repeatIntervalHours; 
  final int repeatIntervalMinutes;

  SyncSchedule({required this.time, required this.repeatIntervalHours, required this.repeatIntervalMinutes});

  Map<String, dynamic> toJson() => {
        'time': time,
        'repeatIntervalHours': repeatIntervalHours,
        'repeatIntervalMinutes': repeatIntervalMinutes,
      };

  factory SyncSchedule.fromJson(Map<String, dynamic> json) {
    return SyncSchedule(
      time: json['time'],
      repeatIntervalHours: json['repeatIntervalHours'],
      repeatIntervalMinutes: json['repeatIntervalMinutes'],
    );
  }
  //toString
  @override
  String toString() {
    return '$time-$repeatIntervalHours-$repeatIntervalMinutes';
  }
}
