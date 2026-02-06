class SyncFaceSchedule {
  final int repeatIntervalHours;
  final int repeatIntervalMinutes;

  SyncFaceSchedule(
      {required this.repeatIntervalHours, required this.repeatIntervalMinutes});

  Map<String, dynamic> toJson() => {
        'repeatIntervalHours': repeatIntervalHours,
        'repeatIntervalMinutes': repeatIntervalMinutes,
      };

  factory SyncFaceSchedule.fromJson(Map<String, dynamic> json) {
    return SyncFaceSchedule(
      repeatIntervalHours: json['repeatIntervalHours'],
      repeatIntervalMinutes: json['repeatIntervalMinutes'],
    );
  }

  @override
  String toString() {
    return '$repeatIntervalHours-$repeatIntervalMinutes';
  }
}
