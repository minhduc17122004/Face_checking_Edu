import 'dart:io';

import 'package:dio/dio.dart';

class RegisterStudent {
  final String studentName;
  final String jobPosition;
  final File? attachment;
  final String pin;
  final int? studentId;
  final String? avatar;
  /// UUID from backend server — used for EDU sync identification
  final String? serverUserId;

  RegisterStudent({
    required this.studentName,
    required this.jobPosition,
    this.attachment,
    required this.pin,
    this.studentId,
    this.avatar,
    this.serverUserId,
  });

  Future<Map<String, dynamic>> toJson() async {
    return {
      'name': studentName,
      'job_title': jobPosition,
      if (attachment != null)
        'file': await MultipartFile.fromFile(attachment!.path,
            filename: attachment!.path.split('/').last),
      'pin': pin,
      if (studentId != null) 'student_id': studentId,
      if (avatar != null) 'avatar': avatar,
    };
  }
}
