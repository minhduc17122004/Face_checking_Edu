import 'package:face_time_keeping/entities/employee.dart';
import 'package:flutter/material.dart';

class UserInfoComponent extends StatelessWidget {
  const UserInfoComponent({
    Key? key,
    this.employee,
  }) : super(key: key);

  final Employee? employee;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.max,
        children: [
          UserInfoField(label: 'Tên', value: employee?.name ?? '-'),
          UserInfoField(label: 'PIN', value: employee?.pin ?? '-'),
          if (employee?.jobTitle != null && employee!.jobTitle is String)
            UserInfoField(label: 'Chức vụ', value: employee!.jobTitle as String),
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
