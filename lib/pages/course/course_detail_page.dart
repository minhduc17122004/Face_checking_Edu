import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:face_time_keeping/common/enums/request_status.dart';
import 'package:face_time_keeping/common/resources/app_colors.dart';
import 'package:face_time_keeping/di/injection.dart';
import 'package:face_time_keeping/entities/course.dart';
import 'package:face_time_keeping/entities/course_student.dart';
import 'package:face_time_keeping/entities/schedule.dart';
import 'package:face_time_keeping/pages/course/bloc/course_bloc.dart';
import 'package:face_time_keeping/pages/course/bloc/course_state.dart';
import 'package:face_time_keeping/pages/schedule/bloc/schedule_bloc.dart';
import 'package:face_time_keeping/pages/schedule/bloc/schedule_state.dart';
import 'package:face_time_keeping/pages/widgets/empty_state_widget.dart';
import 'package:face_time_keeping/data/local/local_service.dart';
import 'package:face_time_keeping/route/navigator.dart';

class CourseDetailPage extends StatefulWidget {
  final Course course;

  const CourseDetailPage({super.key, required this.course});

  @override
  State<CourseDetailPage> createState() => _CourseDetailPageState();
}

class _CourseDetailPageState extends State<CourseDetailPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final CourseBloc _courseBloc;
  late final ScheduleBloc _scheduleBloc;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _courseBloc = getIt<CourseBloc>();
    _scheduleBloc = getIt<ScheduleBloc>();

    _courseBloc.loadCourseDetail(widget.course.id);
    _courseBloc.loadCourseStudents(widget.course.id);
    _scheduleBloc.loadSchedules(courseId: widget.course.id);

    final role = getIt<LocalService>().getUserRole();
    _isAdmin = role.toLowerCase() == 'admin';
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.slate900),
          onPressed: () => AppNavigator.pop(),
        ),
        title: Text(
          widget.course.courseName,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.slate900,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.slate500,
          indicatorColor: AppColors.primary,
          indicatorWeight: 2.5,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.normal,
            fontSize: 13,
          ),
          tabs: const [
            Tab(text: 'Thông tin'),
            Tab(text: 'Học sinh'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildInfoTab(),
          _buildStudentsTab(),
        ],
      ),
    );
  }

  Widget _buildInfoTab() {
    return BlocBuilder<CourseBloc, CourseState>(
      bloc: _courseBloc,
      builder: (context, state) {
        final course = state.selectedCourse ?? widget.course;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoCard(course),
              const SizedBox(height: 16),
              _buildAttendanceConfigCard(course),
              const SizedBox(height: 16),
              _buildScheduleSection(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoCard(Course course) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoHeader('Thông tin học phần'),
          const SizedBox(height: 12),
          _buildInfoRow('Tên học phần', course.courseName),
          if (course.courseCode != null)
            _buildInfoRow('Mã học phần', course.courseCode!),
          const Divider(height: 24),
          _buildInfoHeader('Phân công'),
          const SizedBox(height: 12),
          _buildInfoRow(
            'Giảng viên',
            course.teacherName ?? 'Chưa phân công',
          ),
          _buildInfoRow(
            'Phòng học',
            course.roomName ?? 'Chưa phân công',
          ),
          _buildInfoRow(
            'Phòng ban',
            course.departmentName ?? 'Chưa phân công',
          ),
          const Divider(height: 24),
          _buildInfoHeader('Thông tin khác'),
          const SizedBox(height: 12),
          _buildInfoRow('Sĩ số', '${course.enrolledCount} học sinh'),
          _buildInfoRow(
            'Ngày tạo',
            _formatDate(course.createdAt),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceConfigCard(Course course) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoHeader('Cấu hình điểm danh'),
          const SizedBox(height: 12),
          _buildInfoRow('Chế độ', course.attendanceMode.label),
          _buildInfoRow(
              'Sau khi bắt đầu tiết', '${course.attendanceBeforeMinutes} phút'),
          _buildInfoRow(
              'Thời gian điểm danh', '${course.attendanceAfterMinutes} phút'),
          if (course.attendanceMode == AttendanceMode.custom) ...[
            BlocBuilder<ScheduleBloc, ScheduleState>(
              bloc: _scheduleBloc,
              builder: (context, state) {
                if (state.schedules.isEmpty) return const SizedBox.shrink();
                final schedule = state.schedules.first;
                final ts = schedule.timeSlot;
                if (ts == null) return const SizedBox.shrink();

                int p(String t) {
                  final parts = t.split(':');
                  if (parts.length < 2) return 0;
                  return int.parse(parts[0]) * 60 + int.parse(parts[1]);
                }

                String f(int totalMinutes) {
                  final h = totalMinutes ~/ 60;
                  final m = totalMinutes % 60;
                  return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
                }

                final slotStart = p(ts.startTime);
                final slotEnd = p(ts.endTime);
                final openMin = slotStart + course.attendanceBeforeMinutes;
                final closeMin = (openMin + course.attendanceAfterMinutes)
                    .clamp(openMin, slotEnd);

                return _buildInfoRow(
                  'Khung giờ tùy chỉnh',
                  '${f(openMin)} - ${f(closeMin)}',
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildScheduleSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoHeader('Lịch học'),
          const SizedBox(height: 12),
          BlocBuilder<ScheduleBloc, ScheduleState>(
            bloc: _scheduleBloc,
            builder: (context, state) {
              if (state.requestStatus == RequestStatus.requesting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  ),
                );
              }
              if (state.requestStatus == RequestStatus.success) {
                if (state.schedules.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Chưa có lịch học',
                        style: TextStyle(
                          color: AppColors.slate500,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  );
                }
                return Column(
                  children: state.schedules
                      .map((schedule) => _buildScheduleItem(schedule))
                      .toList(),
                );
              }
              if (state.requestStatus == RequestStatus.failed) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: SelectableText(
                      state.message ?? 'Có lỗi xảy ra',
                      style: const TextStyle(
                        color: AppColors.red,
                        fontSize: 14,
                      ),
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleItem(Schedule schedule) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  schedule.dayName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.slate900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  schedule.timeSlot?.displayTime ?? '',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.slate500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.bold,
        color: AppColors.slate900,
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.slate500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.slate900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentsTab() {
    return BlocConsumer<CourseBloc, CourseState>(
      bloc: _courseBloc,
      listener: (context, state) {
        if (state.requestStatus == RequestStatus.failed &&
            state.message != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: SelectableText(state.message!),
              backgroundColor: AppColors.red,
            ),
          );
        }
      },
      builder: (context, state) {
        if (state.requestStatus == RequestStatus.requesting) {
          return const Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primary,
            ),
          );
        }
        if (state.requestStatus == RequestStatus.success) {
          if (state.students.isEmpty) {
            return EmptyStateWidget(
              title: 'Chưa có học sinh',
              subtitle: 'Thêm học sinh vào học phần này',
              titleAction: 'Thêm học sinh',
              onActionTapped: (ctx) => _showAddStudentDialog(context),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: state.students.length,
            itemBuilder: (context, index) {
              return _buildStudentItem(state.students[index]);
            },
          );
        }
        if (state.requestStatus == RequestStatus.failed) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SelectableText.rich(
                  TextSpan(
                    text: state.message ?? 'Có lỗi xảy ra',
                    style: const TextStyle(color: AppColors.red),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () =>
                      _courseBloc.loadCourseStudents(widget.course.id),
                  child: const Text('Thử lại'),
                ),
              ],
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildStudentItem(CourseStudent student) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: CircleAvatar(
          radius: 22,
          backgroundColor: AppColors.blue50,
          child: Text(
            (student.name ?? 'H')[0].toUpperCase(),
            style: const TextStyle(
              color: AppColors.blue600,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
        title: Text(
          student.name ?? 'Học sinh #${student.studentId}',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.slate900,
          ),
        ),
        subtitle: Row(
          children: [
            if (student.studentCode != null) ...[
              Text(
                '${student.studentCode}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.slate500,
                ),
              ),
              if (student.pin != null) const SizedBox(width: 12),
            ],
            if (student.pin != null)
              Text(
                'PIN: ${student.pin}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.slate500,
                ),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildFaceStatusIcon(student),
            const SizedBox(width: 6),
            _buildEmbeddingBadge(student),
            const SizedBox(width: 8),
            if (_isAdmin)
              PopupMenuButton<String>(
                icon: const Icon(
                  Icons.more_vert,
                  color: AppColors.slate500,
                  size: 20,
                ),
                onSelected: (value) {
                  if (value == 'unenroll') {
                    _confirmUnenrollStudent(student);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'unenroll',
                    child: Row(
                      children: [
                        Icon(Icons.remove_circle_outline,
                            color: AppColors.red, size: 18),
                        SizedBox(width: 8),
                        Text('Xóa khỏi học phần'),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFaceStatusIcon(CourseStudent student) {
    if (student.hasFace) {
      return Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppColors.green100,
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Icon(
          Icons.check_circle,
          color: AppColors.green500,
          size: 16,
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppColors.red100,
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Icon(
          Icons.cancel,
          color: AppColors.red600,
          size: 16,
        ),
      );
    }
  }

  Widget _buildEmbeddingBadge(CourseStudent student) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.slate200,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '${student.embeddingCount} vectors',
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: AppColors.slate500,
        ),
      ),
    );
  }

  void _showAddStudentDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => _AddStudentsDialog(
        courseId: widget.course.id,
        courseBloc: _courseBloc,
      ),
    );
  }

  void _confirmUnenrollStudent(CourseStudent student) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text(
          'Bạn có chắc muốn xóa học sinh "${student.name ?? '#${student.studentId}'}" khỏi học phần này?',
        ),
        actions: [
          TextButton(
            onPressed: () => AppNavigator.pop(),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () {
              _courseBloc.unenrollStudent(widget.course.id, student.studentId);
              AppNavigator.pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.red,
            ),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}

// ─── Add Students Dialog with list selection ─────────────────────────────────

class _AddStudentsDialog extends StatefulWidget {
  final String courseId;
  final CourseBloc courseBloc;

  const _AddStudentsDialog({
    required this.courseId,
    required this.courseBloc,
  });

  @override
  State<_AddStudentsDialog> createState() => _AddStudentsDialogState();
}

class _AddStudentsDialogState extends State<_AddStudentsDialog> {
  final Set<int> _selectedIds = {};
  List<Map<String, dynamic>> _students = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAvailableStudents();
  }

  Future<void> _loadAvailableStudents() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final result =
        await widget.courseBloc.getAvailableStudents(widget.courseId);
    if (mounted) {
      if (result != null) {
        setState(() {
          _students = result;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = widget.courseBloc.state.message ?? 'Có lỗi xảy ra';
          _isLoading = false;
        });
      }
    }
  }

  void _toggleSelection(int id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _toggleSelectAll() {
    setState(() {
      if (_selectedIds.length == _students.length) {
        _selectedIds.clear();
      } else {
        _selectedIds.addAll(_students.map((s) => s['id'] as int));
      }
    });
  }

  Future<void> _enrollSelected() async {
    if (_selectedIds.isEmpty) return;

    AppNavigator.pop();
    final result = await widget.courseBloc.batchEnrollStudents(
      widget.courseId,
      _selectedIds.toList(),
    );

    if (mounted) {
      if (result != null) {
        final enrolled = result['total_enrolled'] as int? ?? 0;
        final already = result['total_already_enrolled'] as int? ?? 0;
        final total = _selectedIds.length;

        String message;
        if (enrolled == total) {
          message = 'Đã thêm thành công $enrolled học sinh.';
        } else if (enrolled > 0) {
          message =
              'Đã thêm $enrolled/$total học sinh. $already học sinh đã tồn tại.';
        } else {
          message = 'Tất cả $already học sinh đã tồn tại trong học phần.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor:
                enrolled > 0 ? AppColors.green600 : AppColors.orange600,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.courseBloc.state.message ?? 'Có lỗi xảy ra'),
            backgroundColor: AppColors.red600,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Thêm học sinh'),
          if (_students.isNotEmpty)
            Text(
              '${_selectedIds.length}/${_students.length}',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.normal,
                color: AppColors.slate500,
              ),
            ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SelectableText(
                          _error!,
                          style: const TextStyle(color: AppColors.red),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadAvailableStudents,
                          child: const Text('Thử lại'),
                        ),
                      ],
                    ),
                  )
                : _students.isEmpty
                    ? const Center(
                        child: Text(
                          'Không có học sinh nào khả dụng',
                          style: TextStyle(color: AppColors.slate500),
                        ),
                      )
                    : Column(
                        children: [
                          // Select all row
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.slate200,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Checkbox(
                                  value:
                                      _selectedIds.length == _students.length,
                                  onChanged: (_) => _toggleSelectAll(),
                                ),
                                const Text(
                                  'Chọn tất cả',
                                  style: TextStyle(fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Student list
                          Expanded(
                            child: ListView.builder(
                              itemCount: _students.length,
                              itemBuilder: (context, index) {
                                final student = _students[index];
                                final id = student['id'] as int;
                                final studentCode =
                                    student['student_code'] as String?;
                                final hasFace =
                                    student['has_face'] as bool? ?? false;
                                final isSelected = _selectedIds.contains(id);

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 4),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? AppColors.blue50
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isSelected
                                          ? AppColors.blue
                                          : AppColors.slate200,
                                    ),
                                  ),
                                  child: ListTile(
                                    dense: true,
                                    leading: Checkbox(
                                      value: isSelected,
                                      onChanged: (_) => _toggleSelection(id),
                                    ),
                                    title: Text(
                                      (student['full_name'] as String?) ??
                                          'HV#$id',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    subtitle: Text(
                                      '${studentCode ?? id}',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    trailing: Icon(
                                      hasFace
                                          ? Icons.face
                                          : Icons.face_outlined,
                                      color: hasFace
                                          ? AppColors.green600
                                          : AppColors.slate400,
                                      size: 20,
                                    ),
                                    onTap: () => _toggleSelection(id),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
      ),
      actions: [
        TextButton(
          onPressed: () => AppNavigator.pop(),
          child: const Text('Hủy'),
        ),
        ElevatedButton(
          onPressed: _selectedIds.isEmpty ? null : _enrollSelected,
          child: Text('Thêm (${_selectedIds.length})'),
        ),
      ],
    );
  }
}
