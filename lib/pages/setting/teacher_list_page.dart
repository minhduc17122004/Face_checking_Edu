import 'package:face_time_keeping/common/api_client/data_state.dart';
import 'package:face_time_keeping/common/resources/app_colors.dart';
import 'package:face_time_keeping/common/resources/styles/text_styles.dart';
import 'package:face_time_keeping/data/models/register_user_request.dart';
import 'package:face_time_keeping/data/remote/user_service.dart';
import 'package:face_time_keeping/di/injection.dart';
import 'package:flutter/material.dart';

class TeacherListPage extends StatefulWidget {
  const TeacherListPage({super.key});

  @override
  State<TeacherListPage> createState() => _TeacherListPageState();
}

class _TeacherListPageState extends State<TeacherListPage> {
  late Future<DataState<List<UserInfo>>> _teachersFuture;

  @override
  void initState() {
    super.initState();
    _fetchTeachers();
  }

  void _fetchTeachers() {
    _teachersFuture = getIt<UserService>().getUsersByRole('teacher');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: Text(
          'Danh sách giáo viên',
          style: TextStyles.blackNormalBold.copyWith(
            fontSize: 18,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppColors.blue,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: FutureBuilder<DataState<List<UserInfo>>>(
        future: _teachersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.blue),
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Lỗi: ${snapshot.error}',
                style: TextStyles.blackNormalRegular.copyWith(color: AppColors.red),
              ),
            );
          }

          final dataState = snapshot.data;
          if (dataState == null || !dataState.isSuccess) {
            return Center(
              child: Text(
                dataState?.error ?? 'Không thể tải danh sách giáo viên',
                style: TextStyles.blackNormalRegular.copyWith(color: AppColors.red),
              ),
            );
          }

          final teachers = dataState.data ?? [];
          if (teachers.isEmpty) {
            return Center(
              child: Text(
                'Chưa có giáo viên nào',
                style: TextStyles.blackNormalRegular.copyWith(
                  color: AppColors.gray200,
                  fontSize: 16,
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {
                _fetchTeachers();
              });
              await _teachersFuture;
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: teachers.length,
              itemBuilder: (context, index) {
                final teacher = teachers[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.blue.withOpacity(0.1)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: AppColors.blue.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            teacher.fullName.isNotEmpty
                                ? teacher.fullName[0].toUpperCase()
                                : 'G',
                            style: TextStyles.blackNormalBold.copyWith(
                              fontSize: 20,
                              color: AppColors.blue,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              teacher.fullName,
                              style: TextStyles.blackNormalBold.copyWith(
                                fontSize: 16,
                                color: AppColors.slate900,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              teacher.email,
                              style: TextStyles.blackNormalRegular.copyWith(
                                fontSize: 13,
                                color: AppColors.slate500,
                              ),
                            ),
                            if (teacher.studentCode != null &&
                                teacher.studentCode!.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.green.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Mã GV: ${teacher.studentCode}',
                                  style: TextStyles.blackNormalBold.copyWith(
                                    fontSize: 11,
                                    color: AppColors.green,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
