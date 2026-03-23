import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:face_time_keeping/common/enums/request_status.dart';
import 'package:face_time_keeping/common/resources/app_colors.dart';
import 'package:face_time_keeping/common/resources/styles/text_styles.dart';
import 'package:face_time_keeping/common/utils/alerts.dart';
import 'package:face_time_keeping/di/injection.dart';
import 'package:face_time_keeping/entities/department.dart';
import 'package:face_time_keeping/pages/department/bloc/department_bloc.dart';
import 'package:face_time_keeping/pages/department/bloc/department_state.dart';
import 'package:face_time_keeping/pages/widgets/empty_state_widget.dart';
import 'package:face_time_keeping/route/app_route.dart';
import 'package:face_time_keeping/route/navigator.dart';

class DepartmentListPage extends StatelessWidget {
  const DepartmentListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final departmentBloc = getIt<DepartmentBloc>()..loadDepartments();
    return BlocProvider.value(
      value: departmentBloc,
      child: _DepartmentListView(departmentBloc: departmentBloc),
    );
  }
}

class _DepartmentListView extends StatefulWidget {
  final DepartmentBloc departmentBloc;

  const _DepartmentListView({required this.departmentBloc});

  @override
  State<_DepartmentListView> createState() => _DepartmentListViewState();
}

class _DepartmentListViewState extends State<_DepartmentListView> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          'QUẢN LÝ PHÒNG BAN',
          style: TextStyle(
            color: AppColors.slate900,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.slate900),
          onPressed: () => AppNavigator.pop(),
        ),
      ),
      body: BlocConsumer<DepartmentBloc, DepartmentState>(
        listener: (context, state) {
          if (state.requestStatus == RequestStatus.failed &&
              state.message != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: SelectableText(state.message!),
                backgroundColor: AppColors.red,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state.requestStatus == RequestStatus.requesting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.requestStatus == RequestStatus.success) {
            if (state.departments.isEmpty) {
              return const EmptyStateWidget(
                title: 'Chưa có phòng ban',
                subtitle: 'Nhấn nút + để thêm phòng ban mới',
              );
            }
            return RefreshIndicator(
              onRefresh: () async {
                widget.departmentBloc.loadDepartments();
              },
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: state.departments.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final dept = state.departments[index];
                  return _DepartmentCard(
                    departmentBloc: widget.departmentBloc,
                    department: dept,
                  );
                },
              ),
            );
          }
          return const SizedBox.shrink();
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await AppNavigator.pushNamed(
            RouterName.departmentForm,
          );
          if (result == true && context.mounted) {
            widget.departmentBloc.loadDepartments();
          }
        },
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

class _DepartmentCard extends StatelessWidget {
  final DepartmentBloc departmentBloc;
  final Department department;

  const _DepartmentCard({
    required this.departmentBloc,
    required this.department,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final result = await AppNavigator.pushNamed(
          RouterName.departmentDetail,
          arguments: department,
        );
        if (context.mounted) {
          if (result == 'deleted') {
            showTopAlert(context,
                title: 'Xoá phòng ban thành công!', type: AlertType.success);
            departmentBloc.loadDepartments();
          } else if (result == true) {
            departmentBloc.loadDepartments();
          }
        }
      },
      child: Container(
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
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.business, color: AppColors.primary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    department.name,
                    style: TextStyles.blackNormalBold,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Mã: ${department.code}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.slate500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: AppColors.slate400),
          ],
        ),
      ),
    );
  }
}
