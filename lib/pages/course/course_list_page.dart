import 'package:face_time_keeping/common/enums/request_status.dart';
import 'package:face_time_keeping/common/resources/app_colors.dart';
import 'package:face_time_keeping/common/resources/styles/text_styles.dart';
import 'package:face_time_keeping/di/injection.dart';
import 'package:face_time_keeping/entities/course.dart';
import 'package:face_time_keeping/pages/course/bloc/course_bloc.dart';
import 'package:face_time_keeping/pages/course/bloc/course_state.dart';
import 'package:face_time_keeping/pages/widgets/empty_state_widget.dart';
import 'package:face_time_keeping/route/app_route.dart';
import 'package:face_time_keeping/route/navigator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:face_time_keeping/pages/setting/cubit/setting/setting_cubit.dart';

class CourseListPage extends StatelessWidget {
  const CourseListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final courseBloc = getIt<CourseBloc>();
    return BlocProvider.value(
      value: courseBloc,
      child: _CourseListView(courseBloc: courseBloc),
    );
  }
}

class _CourseListView extends StatefulWidget {
  final CourseBloc courseBloc;

  const _CourseListView({required this.courseBloc});

  @override
  State<_CourseListView> createState() => _CourseListViewState();
}

class _CourseListViewState extends State<_CourseListView>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  late final SettingCubit _settingCubit = getIt<SettingCubit>();
  bool _isAdmin = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadUserRole();
  }

  Future<void> _loadUserRole() async {
    final role = await _settingCubit.getUserRole();
    if (mounted) {
      setState(() {
        _isAdmin = role.toLowerCase() == 'admin';
        if (!_loaded) {
          _loaded = true;
          widget.courseBloc.loadCourses(mine: !_isAdmin);
        }
      });
    }
  }

  void _refreshCourses() {
    widget.courseBloc.loadCourses(mine: !_isAdmin);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
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
      ),
      floatingActionButton: _isAdmin
          ? FloatingActionButton(
              onPressed: () async {
                final result =
                    await AppNavigator.pushNamed(RouterName.courseForm);
                if (result == true && context.mounted) {
                  widget.courseBloc.loadCourses(mine: !_isAdmin);
                }
              },
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
      body: BlocConsumer<CourseBloc, CourseState>(
        listener: (context, state) {
          if (state.requestStatus == RequestStatus.failed &&
              state.message != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: SelectableText(state.message!),
                backgroundColor: AppColors.red600,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state.requestStatus == RequestStatus.requesting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state.requestStatus == RequestStatus.failed &&
              state.message != null &&
              state.courses.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline,
                      size: 48, color: AppColors.red600),
                  const SizedBox(height: 16),
                  Text(
                    state.message!,
                    style: TextStyles.blackNormalRegular,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      widget.courseBloc.loadCourses(mine: !_isAdmin);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Thử lại'),
                  ),
                ],
              ),
            );
          }

          if (state.requestStatus == RequestStatus.success ||
              (state.requestStatus == RequestStatus.failed &&
                  state.courses.isNotEmpty)) {
            if (state.courses.isEmpty) {
              return const EmptyStateWidget(
                title: 'Chưa có học phần',
                subtitle: 'Bạn chưa được gán học phần nào',
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: state.courses.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final course = state.courses[index];
                return _CourseCard(
                  courseBloc: widget.courseBloc,
                  course: course,
                  isAdmin: _isAdmin,
                  onTap: () async {
                    await AppNavigator.pushNamed(RouterName.courseDetail,
                        arguments: course);
                    if (context.mounted) {
                      _refreshCourses();
                    }
                  },
                  onEdit: () async {
                    final result = await AppNavigator.pushNamed(
                        RouterName.courseForm,
                        arguments: course);
                    if (result == true && context.mounted) {
                      _refreshCourses();
                    }
                  },
                  onDelete: () => _showDeleteDialog(context, course),
                );
              },
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, Course course) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content:
            Text('Bạn có chắc chắn muốn xóa học phần "${course.courseName}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              widget.courseBloc.deleteCourse(course.id);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.red600,
              foregroundColor: Colors.white,
            ),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
  }
}

class _CourseCard extends StatelessWidget {
  final CourseBloc courseBloc;
  final Course course;
  final bool isAdmin;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CourseCard({
    required this.courseBloc,
    required this.course,
    required this.isAdmin,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  Color _getAttendanceModeColor() {
    switch (course.attendanceMode) {
      case AttendanceMode.preset:
        return AppColors.blue600;
      case AttendanceMode.flexible:
        return AppColors.purple600;
      case AttendanceMode.custom:
        return AppColors.teal600;
    }
  }

  Color _getAttendanceModeBackgroundColor() {
    switch (course.attendanceMode) {
      case AttendanceMode.preset:
        return AppColors.blue50;
      case AttendanceMode.flexible:
        return AppColors.purple50;
      case AttendanceMode.custom:
        return AppColors.teal50;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.blue50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.school,
                    color: AppColors.blue600,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        course.courseName,
                        style: TextStyles.blackNormalBold.copyWith(
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        course.courseCode ?? 'Chưa có mã',
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.slate500,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isAdmin) ...[
                  IconButton(
                    icon: const Icon(Icons.edit_outlined,
                        size: 20, color: AppColors.blue600),
                    onPressed: onEdit,
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline,
                        size: 20, color: AppColors.red600),
                    onPressed: onDelete,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getAttendanceModeBackgroundColor(),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    course.attendanceMode.shortLabel,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _getAttendanceModeColor(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Icon(Icons.people, size: 16, color: AppColors.slate500),
                const SizedBox(width: 4),
                Text(
                  '${course.enrolledCount} sinh viên',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.slate500,
                  ),
                ),
                if (course.roomName != null) ...[
                  const SizedBox(width: 12),
                  const Icon(Icons.meeting_room_outlined,
                      size: 16, color: AppColors.slate500),
                  const SizedBox(width: 4),
                  Text(
                    course.roomName!,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.slate500,
                    ),
                  ),
                ],
              ],
            ),
            if (course.dayOfWeek != null && course.timeSlotName != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.calendar_month_outlined,
                      size: 16, color: AppColors.slate500),
                  const SizedBox(width: 4),
                  Text(
                    '${_getDayLabel(course.dayOfWeek!)} - ${course.timeSlotName}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.slate500,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _getDayLabel(int day) {
    const days = {
      1: 'Thứ 2',
      2: 'Thứ 3',
      3: 'Thứ 4',
      4: 'Thứ 5',
      5: 'Thứ 6',
      6: 'Thứ 7',
      7: 'Chủ Nhật',
    };
    return days[day] ?? '???';
  }
}
