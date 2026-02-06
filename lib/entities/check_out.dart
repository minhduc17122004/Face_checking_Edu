class CheckOut {
  final DateTime time;
  final String? pin;
  final String name;
  final int employeeId;
  CheckOut({
    required this.time,
    this.pin,
    required this.name,
    required this.employeeId,
  });

  // factory CheckOut.fromJson(Map<String, dynamic> json) => CheckOut(
  //       time: DateTime.tryParse(json['time'].toString())!,
  //       pin:
  //           json['pin'] is String ? json['pin'] : json['pin']?.toString() ?? '',
  //       name: json['name'] is String
  //           ? json['name']
  //           : json['name']?.toString() ?? '',
  //     );
}
