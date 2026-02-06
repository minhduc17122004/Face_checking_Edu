
class VerifyEmployee {
  String? name;
  String? pin;
  int employeeId;
  bool? checkIn;

  VerifyEmployee({this.name, this.pin, this.checkIn, required this.employeeId});

  VerifyEmployee.fromJson(Map<String, dynamic> json): employeeId = json['employee_id'] {
    name = json['name'];
    pin = json['pin'];
    checkIn = json['check_in'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['name'] = name;
    data['pin'] = pin;
    data['check_in'] = checkIn;
    data['employee_id'] = employeeId;
    return data;
  }
}
