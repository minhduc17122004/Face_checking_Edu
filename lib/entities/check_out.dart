class CheckOut {
  final DateTime time;
  final String? pin;
  final String name;
  final int studentId;
  CheckOut({
    required this.time,
    this.pin,
    required this.name,
    required this.studentId,
  });
}
