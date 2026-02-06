import 'dart:io';

import 'package:dio/dio.dart';

class RegisterEmployee {
  final String employeeName;
  final String jobPosition;
  final File? attachment;
  final String pin; //only number
  final int? employeeId;
  final String? avatar;

  RegisterEmployee({
    required this.employeeName,
    required this.jobPosition,
    this.attachment,
    required this.pin,
    this.employeeId,
    this.avatar,
  });

  Future<Map<String, dynamic>> toJson() async {
    return {
      'name': employeeName,
      'job_title': jobPosition,
      if (attachment != null)
        'file': await MultipartFile.fromFile(attachment!.path,
            filename: attachment!.path.split('/').last),
      'pin': pin,
      if (employeeId != null) 'employee_id': employeeId,
      if (avatar != null) 'avatar': avatar,
    };
  }
}
