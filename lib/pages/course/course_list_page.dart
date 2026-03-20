import 'package:flutter/material.dart';
import 'package:face_time_keeping/common/resources/index.dart';

class CourseMock {
  final String id;
  final String courseName;
  final String? subject;
  final String? courseCode;

  CourseMock({
    required this.id,
    required this.courseName,
    this.subject,
    this.courseCode,
  });
}

class CourseListPage extends StatefulWidget {
  const CourseListPage({super.key});

  @override
  State<CourseListPage> createState() => _CourseListPageState();
}

class _CourseListPageState extends State<CourseListPage> {
  // Dump data theo cấu trúc của schema v1/course.py model từ backend
  final List<CourseMock> _mockCourses = [
    CourseMock(
      id: '1',
      courseCode: 'CS101',
      courseName: 'Nhập môn Trí tuệ nhân tạo',
      subject: 'Trí tuệ nhân tạo',
    ),
    CourseMock(
      id: '2',
      courseCode: 'SE102',
      courseName: 'Công nghệ phần mềm',
      subject: 'Kỹ thuật phần mềm',
    ),
    CourseMock(
      id: '3',
      courseCode: 'DB103',
      courseName: 'Cơ sở dữ liệu phân tán',
      subject: 'Hệ thống thông tin',
    ),
    CourseMock(
      id: '4',
      courseCode: 'NW104',
      courseName: 'Mạng máy tính cơ bản',
      subject: 'Mạng và truyền thông',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          'DANH SÁCH HỌC PHẦN',
          style: TextStyle(
            color: AppColors.slate900,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        automaticallyImplyLeading: false,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: AppColors.slate900),
                onPressed: () => Navigator.pop(context),
              )
            : null,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16.0),
        itemCount: _mockCourses.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final course = _mockCourses[index];
          return _buildCourseCard(course);
        },
      ),
    );
  }

  Widget _buildCourseCard(CourseMock course) {
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
                course.courseCode ?? 'Chưa có mã',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.green100.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Học phần',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.green600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            course.courseName,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.slate900,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.menu_book_rounded,
                  size: 16, color: AppColors.slate500),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  course.subject ?? 'Không có thông tin môn học',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.slate500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
