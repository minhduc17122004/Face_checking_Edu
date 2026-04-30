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
import 'package:flutter/services.dart';
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
  bool _isTeacher = false;
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
        _isTeacher = role.toLowerCase() == 'teacher';
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
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: BlocConsumer<CourseBloc, CourseState>(
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

            return RefreshIndicator(
              onRefresh: () async => _refreshCourses(),
              color: AppColors.primary,
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: state.courses.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                final course = state.courses[index];
                return _CourseCard(
                  courseBloc: widget.courseBloc,
                  course: course,
                  isAdmin: _isAdmin,
                  isTeacher: _isTeacher,
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
                  onEditAttendance: () async {
                    final changed =
                        await _showAttendanceConfigSheet(context, course);
                    if (changed == true && context.mounted) {
                      _refreshCourses();
                    }
                  },
                  onDelete: () => _showDeleteDialog(context, course),
                );
              },
            ),
          );
          }

          return const SizedBox.shrink();
        },
      ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: AppColors.slate200, width: 0.5),
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back, color: AppColors.slate900),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ),
          const Text(
            'DANH SÁCH HỌC PHẦN',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.slate900,
            ),
          ),
        ],
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

  Future<bool?> _showAttendanceConfigSheet(
      BuildContext context, Course course) async {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AttendanceConfigSheet(
        course: course,
        courseBloc: widget.courseBloc,
      ),
    );
  }
}

class _CourseCard extends StatelessWidget {
  final CourseBloc courseBloc;
  final Course course;
  final bool isAdmin;
  final bool isTeacher;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onEditAttendance;
  final VoidCallback onDelete;

  const _CourseCard({
    required this.courseBloc,
    required this.course,
    required this.isAdmin,
    this.isTeacher = false,
    required this.onTap,
    required this.onEdit,
    required this.onEditAttendance,
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
                ] else if (isTeacher) ...[
                  IconButton(
                    tooltip: 'Cấu hình điểm danh',
                    icon: const Icon(Icons.tune_rounded,
                        size: 20, color: AppColors.teal600),
                    onPressed: onEditAttendance,
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

// ─────────────────────────────────────────────────────────────────────────────
// Attendance Config Bottom Sheet  (Teacher-only)
// ─────────────────────────────────────────────────────────────────────────────

class _AttendanceConfigSheet extends StatefulWidget {
  final Course course;
  final CourseBloc courseBloc;

  const _AttendanceConfigSheet({
    required this.course,
    required this.courseBloc,
  });

  @override
  State<_AttendanceConfigSheet> createState() => _AttendanceConfigSheetState();
}

class _AttendanceConfigSheetState extends State<_AttendanceConfigSheet> {
  late AttendanceMode _mode;
  late final TextEditingController _startCtrl;
  late final TextEditingController _endCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _mode = widget.course.attendanceMode;
    _startCtrl = TextEditingController(
        text: widget.course.customWindowStartMinutes.toString());
    _endCtrl = TextEditingController(
        text: widget.course.customWindowEndMinutes.toString());
  }

  @override
  void dispose() {
    _startCtrl.dispose();
    _endCtrl.dispose();
    super.dispose();
  }

  Color _modeColor(AttendanceMode m) {
    switch (m) {
      case AttendanceMode.preset:
        return AppColors.blue600;
      case AttendanceMode.flexible:
        return AppColors.purple600;
      case AttendanceMode.custom:
        return AppColors.teal600;
    }
  }

  Color _modeBg(AttendanceMode m) {
    switch (m) {
      case AttendanceMode.preset:
        return AppColors.blue50;
      case AttendanceMode.flexible:
        return AppColors.purple50;
      case AttendanceMode.custom:
        return AppColors.teal50;
    }
  }

  IconData _modeIcon(AttendanceMode m) {
    switch (m) {
      case AttendanceMode.preset:
        return Icons.schedule;
      case AttendanceMode.flexible:
        return Icons.tune;
      case AttendanceMode.custom:
        return Icons.settings_suggest;
    }
  }

  String _modeDescription(AttendanceMode m) {
    switch (m) {
      case AttendanceMode.preset:
        return 'Mở/đóng điểm danh theo tiết học chuẩn';
      case AttendanceMode.flexible:
        return 'Giáo viên mở/đóng thủ công theo ý muốn';
      case AttendanceMode.custom:
        return 'Tùy chỉnh số phút mở & đóng theo tiết';
    }
  }

  Future<void> _save() async {
    final start = int.tryParse(_startCtrl.text) ?? 0;
    final end = int.tryParse(_endCtrl.text) ?? 30;

    if (_mode == AttendanceMode.custom && end <= start) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Phút kết thúc phải lớn hơn phút bắt đầu'),
          backgroundColor: AppColors.red600,
        ),
      );
      return;
    }

    setState(() => _saving = true);
    await widget.courseBloc.updateCourse(
      id: widget.course.id,
      attendanceMode: _mode,
      customWindowStartMinutes: start,
      customWindowEndMinutes: end,
    );
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(24, 16, 24, 24 + bottomPad),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.slate300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.teal50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.tune_rounded,
                      color: AppColors.teal600, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Cấu hình điểm danh',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.slate900,
                        ),
                      ),
                      Text(
                        widget.course.courseName,
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.slate500),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Mode selection
            const Text(
              'Chế độ điểm danh',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.slate700),
            ),
            const SizedBox(height: 10),
            ...AttendanceMode.values.map((m) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _mode = m),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: _mode == m
                            ? _modeBg(m)
                            : AppColors.backgroundLight,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color:
                              _mode == m ? _modeColor(m) : AppColors.slate200,
                          width: _mode == m ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(_modeIcon(m),
                              color: _mode == m
                                  ? _modeColor(m)
                                  : AppColors.slate400,
                              size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  m.label,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: _mode == m
                                        ? _modeColor(m)
                                        : AppColors.slate700,
                                  ),
                                ),
                                Text(
                                  _modeDescription(m),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: _mode == m
                                        ? _modeColor(m).withOpacity(0.8)
                                        : AppColors.slate500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_mode == m)
                            Icon(Icons.check_circle,
                                color: _modeColor(m), size: 20),
                        ],
                      ),
                    ),
                  ),
                )),
            // Custom minute fields — shown only for 'custom' mode
            if (_mode == AttendanceMode.custom) ...[
              const SizedBox(height: 16),
              const Text(
                'Cửa sổ điểm danh (phút so với đầu tiết)',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.slate700),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                      child: _minuteField(
                          controller: _startCtrl,
                          label: 'Bắt đầu',
                          color: AppColors.teal600)),
                  const SizedBox(width: 12),
                  Expanded(
                      child: _minuteField(
                          controller: _endCtrl,
                          label: 'Kết thúc',
                          color: AppColors.teal600)),
                ],
              ),
            ],
            const SizedBox(height: 28),
            // Save button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.teal600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  disabledBackgroundColor: AppColors.slate300,
                ),
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Lưu cấu hình',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _minuteField({
    required TextEditingController controller,
    required String label,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.slate700)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(3),
          ],
          decoration: InputDecoration(
            hintText: '30',
            hintStyle: const TextStyle(color: AppColors.slate400),
            suffixText: 'phút',
            suffixStyle: const TextStyle(color: AppColors.slate500),
            filled: true,
            fillColor: AppColors.teal50,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: color.withOpacity(0.5))),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: color.withOpacity(0.5))),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: color, width: 2)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
        ),
      ],
    );
  }
}
