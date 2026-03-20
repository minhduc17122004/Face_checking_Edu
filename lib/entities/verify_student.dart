class VerifyStudent {
  String? name;
  String? pin;
  int studentId;
  bool? checkIn;

  VerifyStudent({this.name, this.pin, this.checkIn, required this.studentId});

  VerifyStudent.fromJson(Map<String, dynamic> json): studentId = json['student_id'] {
    name = json['name'];
    pin = json['pin'];
    checkIn = json['check_in'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['name'] = name;
    data['pin'] = pin;
    data['check_in'] = checkIn;
    data['student_id'] = studentId;
    return data;
  }
}
