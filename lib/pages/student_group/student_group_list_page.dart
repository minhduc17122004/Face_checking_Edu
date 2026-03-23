import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:face_time_keeping/common/enums/request_status.dart';
import 'package:face_time_keeping/common/resources/index.dart';
import 'package:face_time_keeping/common/utils/alerts.dart';
import 'package:face_time_keeping/di/injection.dart';
import 'package:face_time_keeping/entities/student_group.dart';
import 'package:face_time_keeping/pages/student_group/bloc/student_group_cubit.dart';
import 'package:face_time_keeping/pages/student_group/bloc/student_group_state.dart';
import 'package:face_time_keeping/pages/widgets/empty_state_widget.dart';
import 'package:face_time_keeping/route/app_route.dart';
import 'package:face_time_keeping/route/navigator.dart';

class StudentGroupListPage extends StatelessWidget {
  const StudentGroupListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => getIt<StudentGroupCubit>()..loadStudentGroups(),
      child: const StudentGroupListView(),
    );
  }
}

class StudentGroupListView extends StatelessWidget {
  const StudentGroupListView({super.key});

  Future<void> _openForm(BuildContext context, {StudentGroup? group}) async {
    final result = await AppNavigator.pushNamed(
      RouterName.studentGroupForm,
      arguments: group,
    );
    if (result == true && context.mounted) {
      context.read<StudentGroupCubit>().loadStudentGroups();
    }
  }

  Future<void> _deleteGroup(BuildContext context, StudentGroup group) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xóa lớp học'),
        content: Text(
            'Bạn có chắc muốn xóa lớp "${group.name ?? group.code}" không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.red),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    if (context.mounted) {
      final success =
          await context.read<StudentGroupCubit>().deleteStudentGroup(group.id);
      if (context.mounted) {
        if (success) {
          showTopAlert(
            context,
            title: 'Xóa lớp học thành công!',
            type: AlertType.success,
          );
        } else {
          final error = context.read<StudentGroupCubit>().state.message;
          showTopAlert(
            context,
            title: error ?? 'Xóa lớp học thất bại',
            type: AlertType.error,
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          'QUẢN LÝ LỚP HỌC',
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
      body: BlocBuilder<StudentGroupCubit, StudentGroupState>(
        builder: (context, state) {
          if (state.requestStatus == RequestStatus.requesting &&
              state.studentGroups.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          if (state.requestStatus == RequestStatus.failed &&
              state.studentGroups.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    state.message ?? 'Có lỗi xảy ra khi tải danh sách lớp học',
                    style: const TextStyle(color: AppColors.red),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () =>
                        context.read<StudentGroupCubit>().loadStudentGroups(),
                    child: const Text('Thử lại'),
                  ),
                ],
              ),
            );
          }

          if (state.studentGroups.isEmpty) {
            return const EmptyStateWidget(
              title: 'Chưa có lớp học',
              subtitle: 'Nhấn nút + để thêm lớp học',
            );
          }

          return RefreshIndicator(
            onRefresh: () =>
                context.read<StudentGroupCubit>().loadStudentGroups(),
            child: ListView.separated(
              padding: const EdgeInsets.all(16.0),
              itemCount: state.studentGroups.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final group = state.studentGroups[index];
                return _buildGroupCard(context, group);
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(context),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildGroupCard(BuildContext context, StudentGroup group) {
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
                group.name ?? group.code,
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
                  color: AppColors.blue50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Lớp học',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.blue600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Department info
          Row(
            children: [
              const Icon(Icons.business_outlined,
                  size: 16, color: AppColors.slate500),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  group.departmentName ?? 'Không có thông tin khoa',
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
          // Advisor info
          if (group.advisorName != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.person_outline,
                    size: 16, color: AppColors.slate500),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'GVCN: ${group.advisorName}',
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
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () => _openForm(context, group: group),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Sửa'),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () => _deleteGroup(context, group),
                icon: const Icon(
                  Icons.delete_outline,
                  size: 18,
                  color: AppColors.red,
                ),
                label: const Text(
                  'Xóa',
                  style: TextStyle(color: AppColors.red),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}