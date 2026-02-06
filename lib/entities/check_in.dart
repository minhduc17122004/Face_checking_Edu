class CheckIn {
  DateTime time;
  String? pin;
  int? minutesLate;
  String imagePath;
  String employeeName;
  CheckIn(
      {required this.time,
      required this.pin,
      this.minutesLate,
      required this.imagePath,
      required this.employeeName});

  // CheckIn.fromJson(Map<String, dynamic> json) {
  //   checkIn = DateFormat('yyyy-MM-dd HH:mm:ss').parse(json['check_in'], true).toLocal();
  //   xCheckinLat = json['x_checkin_lat'];
  //   xCheckinLong = json['x_checkin_long'];
  //   xImgUrlCheckin = json['x_img_url_checkin'];
  //   atOffice = json['at_office'];
  //   employeeId = json['employee_id'];
  //   isLate = json['is_late'];
  // }

  // Map<String, dynamic> toJson() {
  //   final Map<String, dynamic> data = <String, dynamic>{};
  //   data['check_in'] = checkIn;
  //   data['x_checkin_lat'] = xCheckinLat;
  //   data['x_checkin_long'] = xCheckinLong;
  //   data['x_img_url_checkin'] = xImgUrlCheckin;
  //   data['at_office'] = atOffice;
  //   data['employee_id'] = employeeId;
  //   data['is_late'] = isLate;
  //   return data;
  // }
}
