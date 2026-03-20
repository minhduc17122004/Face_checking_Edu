import 'package:flutter/material.dart';
import 'package:face_time_keeping/common/resources/index.dart';

class StudentGroupMock {
  final String id;
  final String code;
  final String? name;
  final String? faculty;
  final String? courseYear;
  final int studentCount;

  StudentGroupMock({
    required this.id,
    required this.code,
    this.name,
    this.faculty,
    this.courseYear,
    required this.studentCount,
  });
}

class StudentGroupListPage extends StatefulWidget {
  const StudentGroupListPage({super.key});

  @override
  State<StudentGroupListPage> createState() => _StudentGroupListPageState();
}

class _StudentGroupListPageState extends State<StudentGroupListPage> {
  // Dump data theo cấu trúc của student_group.py model từ backend
  final List<StudentGroupMock> _mockGroups = [
    StudentGroupMock(
      id: '1',
      code: '48K21.1',
      name: 'Lớp Hệ thống thông tin quản lý',
      faculty: 'Khoa Công Nghệ Thông Tin',
      courseYear: 'K21',
      studentCount: 45,
    ),
    StudentGroupMock(
      id: '2',
      code: '48K21.2',
      name: 'Lớp Hệ thống thông tin',
      faculty: 'Khoa Công Nghệ Thông Tin',
      courseYear: 'K21',
      studentCount: 42,
    ),
    StudentGroupMock(
      id: '3',
      code: '47K20.1',
      name: 'Lớp Khoa học máy tính',
      faculty: 'Khoa Công Nghệ Thông Tin',
      courseYear: 'K20',
      studentCount: 38,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text(
          'Danh sách lớp học',
          style: TextStyle(
            color: AppColors.slate900,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.slate900),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16.0),
        itemCount: _mockGroups.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final group = _mockGroups[index];
          return _buildGroupCard(group);
        },
      ),
    );
  }

  Widget _buildGroupCard(StudentGroupMock group) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                group.code,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.blue50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${group.studentCount} SV',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.blue600,
                  ),
                ),
              ),
            ],
          ),
          if (group.name != null) ...[
            const SizedBox(height: 8),
            Text(
              group.name!,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: AppColors.slate900,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.school_outlined, size: 16, color: AppColors.slate500),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  group.faculty ?? 'Không có thông tin Khoa',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.slate500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (group.courseYear != null) ...[
                const SizedBox(width: 8),
                Container(
                  width: 4,
                  height: 4,
                  decoration: const BoxDecoration(
                    color: AppColors.slate300,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Khóa ${group.courseYear}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.slate500,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
