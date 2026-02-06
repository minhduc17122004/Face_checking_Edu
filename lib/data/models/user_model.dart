import '../../../entities/user.dart';

class UserModel extends User {
  UserModel.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    barcode = json['barcode'] is bool ? null : json['barcode'];
    name = json['name'];
    employeeCode = json['employee_code'] is bool ? null : json['employee_code'];
    jobTitle = json['job_title'] is bool ? null : json['job_title'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['barcode'] = barcode;
    data['name'] = name;
    data['employee_code'] = employeeCode;
    data['job_title'] = jobTitle;
    return data;
  }
}
