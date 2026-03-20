class CheckIn {
  DateTime time;
  String? pin;
  int? minutesLate;
  String imagePath;
  String studentName;
  CheckIn(
      {required this.time,
      required this.pin,
      this.minutesLate,
      required this.imagePath,
      required this.studentName});
}
