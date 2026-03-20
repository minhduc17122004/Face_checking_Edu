import 'package:face_time_keeping/entities/student.dart';
import 'package:flutter/material.dart';

class UserInfoComponent extends StatelessWidget {
  const UserInfoComponent({
    Key? key,
    this.student,
  }) : super(key: key);

  final Student? student;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.max,
        children: [
          UserInfoField(label: 'Tên', value: student?.name ?? '-'),
          UserInfoField(label: 'PIN', value: student?.pin ?? '-'),
          if (student?.jobTitle != null && student!.jobTitle is String)
            UserInfoField(label: 'Lớp', value: student!.jobTitle as String),
        ],
      ),
    );
  }
}

class UserInfoField extends StatelessWidget {
  final String label;
  final String value;

  const UserInfoField({
    Key? key,
    required this.label,
    required this.value,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
