/// UI display model for a successful EDU face check-in.
/// This is NOT persisted — it is produced after a successful API call
/// or after a pending record is confirmed synced.
class EduCheckIn {
  final String studentName;
  final int studentId;
  final DateTime checkinTime;

  /// Backend-resolved status: 'early', 'on_time', 'late', 'present'
  final String status;

  /// Positive = late, negative = early (in minutes)
  final int? minutesDiff;

  /// Human-readable result message from backend
  final String message;

  /// Compressed image path saved locally
  final String? imagePath;

  const EduCheckIn({
    required this.studentName,
    required this.studentId,
    required this.checkinTime,
    required this.status,
    this.minutesDiff,
    required this.message,
    this.imagePath,
  });

  bool get isEarly => status == 'early';
  bool get isOnTime => status == 'on_time';
  bool get isLate => status == 'late';

  String get statusLabel {
    switch (status) {
      case 'early':
        return 'Đến sớm';
      case 'on_time':
        return 'Đúng giờ';
      case 'late':
        return 'Trễ';
      default:
        return 'Có mặt';
    }
  }
}
