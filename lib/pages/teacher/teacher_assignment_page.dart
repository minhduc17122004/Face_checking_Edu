import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:face_time_keeping/common/enums/request_status.dart';
import 'package:face_time_keeping/common/resources/app_colors.dart';
import 'package:face_time_keeping/di/injection.dart';
import 'package:face_time_keeping/entities/course.dart';
import 'package:face_time_keeping/entities/course_student.dart';
import 'package:face_time_keeping/entities/department.dart';
import 'package:face_time_keeping/pages/course/bloc/course_bloc.dart';
import 'package:face_time_keeping/pages/course/bloc/course_state.dart';
import 'package:face_time_keeping/pages/department/bloc/department_bloc.dart';
import 'package:face_time_keeping/pages/department/bloc/department_state.dart';
import 'package:face_time_keeping/pages/teacher/bloc/teacher_bloc.dart';
import 'package:face_time_keeping/pages/teacher/bloc/teacher_state.dart';
import 'package:face_time_keeping/pages/widgets/empty_state_widget.dart';
import 'package:face_time_keeping/route/navigator.dart';

class TeacherAssignmentPage extends StatefulWidget {
  const TeacherAssignmentPage({super.key});

  @override
  State<TeacherAssignmentPage> createState() => _TeacherAssignmentPageState();
}

class _TeacherAssignmentPageState extends State<TeacherAssignmentPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final TeacherBloc _teacherBloc;
  late final DepartmentBloc _departmentBloc;
  late final CourseBloc _courseBloc;

  Department? _selectedDepartment;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _teacherBloc = getIt<TeacherBloc>();
    _departmentBloc = getIt<DepartmentBloc>();
    _courseBloc = getIt<CourseBloc>();

    _departmentBloc.loadDepartments();
    _teacherBloc.loadTeachers();
    _courseBloc.loadCourses();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _onDepartmentSelected(Department? department) {
    setState(() {
      _selectedDepartment = department;
    });
    if (department != null) {
      _teacherBloc.loadTeachers(departmentId: department.id);
    } else {
      _teacherBloc.loadTeachers();
    }
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
        title: const Text(
          'GÁN GIÁO VIÊN',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.slate900,
          ),
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
            Tab(text: 'Phân công'),
            Tab(text: 'Học phần'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAssignmentTab(),
          _buildCoursesTab(),
        ],
      ),
    );
  }

  Widget _buildAssignmentTab() {
    return Column(
      children: [
        _buildDepartmentSelector(),
        Expanded(
          child: _selectedDepartment == null
              ? _buildSelectDepartmentPrompt()
              : _buildTeacherList(),
        ),
      ],
    );
  }

  Widget _buildDepartmentSelector() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Chọn phòng ban',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.slate500,
            ),
          ),
          const SizedBox(height: 8),
          BlocBuilder<DepartmentBloc, DepartmentState>(
            bloc: _departmentBloc,
            builder: (context, state) {
              if (state.requestStatus == RequestStatus.requesting) {
                return Container(
                  height: 48,
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.slate300),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                );
              }
              if (state.requestStatus == RequestStatus.success) {
                return Container(
                  decoration: BoxDecoration(
                    color: AppColors.backgroundLight,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.slate300),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<Department>(
                      value: _selectedDepartment,
                      isExpanded: true,
                      hint: const Text(
                        'Chọn phòng ban',
                        style: TextStyle(
                          color: AppColors.slate400,
                          fontSize: 14,
                        ),
                      ),
                      icon: const Icon(
                        Icons.keyboard_arrow_down,
                        color: AppColors.slate500,
                      ),
                      dropdownColor: Colors.white,
                      items: state.departments.map((dept) {
                        return DropdownMenuItem<Department>(
                          value: dept,
                          child: Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  dept.name,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: AppColors.slate900,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                '${dept.teacherCount} GV',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.slate500,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: _onDepartmentSelected,
                    ),
                  ),
                );
              }
              if (state.requestStatus == RequestStatus.failed) {
                return _buildRetryWidget(
                  state.message ?? 'Có lỗi xảy ra',
                  () => _departmentBloc.loadDepartments(),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSelectDepartmentPrompt() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.business_outlined,
            size: 64,
            color: AppColors.slate300,
          ),
          SizedBox(height: 16),
          Text(
            'Vui lòng chọn phòng ban',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.slate500,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Chọn phòng ban để xem danh sách giáo viên',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.slate400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeacherList() {
    return BlocConsumer<TeacherBloc, TeacherState>(
      bloc: _teacherBloc,
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
          if (state.teachers.isEmpty) {
            return const EmptyStateWidget(
              title: 'Không có giáo viên',
              subtitle: 'Phòng ban này chưa có giáo viên nào',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: state.teachers.length,
            itemBuilder: (context, index) {
              return _buildTeacherCard(state.teachers[index]);
            },
          );
        }
        if (state.requestStatus == RequestStatus.failed) {
          return _buildRetryWidget(
            state.message ?? 'Có lỗi xảy ra',
            () => _teacherBloc.loadTeachers(departmentId: _selectedDepartment?.id),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildTeacherCard(Teacher teacher) {
    final isAssigned = teacher.departmentId != null;
    final departmentName = teacher.departmentName;
    final isInCurrentDepartment =
        isAssigned && teacher.departmentId == _selectedDepartment?.id;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.blue50,
            child: Text(
              teacher.userId.isNotEmpty
                  ? teacher.userId[0].toUpperCase()
                  : 'G',
              style: const TextStyle(
                color: AppColors.blue600,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  teacher.userId,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.slate900,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    if (teacher.teacherId != null) ...[
                      Text(
                        'Mã GV: ${teacher.teacherId}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.slate500,
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    if (teacher.phone != null)
                      Row(
                        children: [
                          const Icon(
                            Icons.phone,
                            size: 12,
                            color: AppColors.slate400,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            teacher.phone!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.slate500,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                _buildDepartmentChip(
                  departmentName ?? 'Chưa gán',
                  isInCurrentDepartment,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _buildActionButton(teacher, isAssigned, isInCurrentDepartment),
        ],
      ),
    );
  }

  Widget _buildDepartmentChip(String departmentName, bool isCurrentDepartment) {
    final bool isUnassigned = departmentName == 'Chưa gán';
    final bgColor = isUnassigned
        ? AppColors.slate200
        : (isCurrentDepartment ? AppColors.green100 : AppColors.blue50);
    final textColor = isUnassigned
        ? AppColors.slate500
        : (isCurrentDepartment ? AppColors.green600 : AppColors.blue600);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        departmentName,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildActionButton(
    Teacher teacher,
    bool isAssigned,
    bool isInCurrentDepartment,
  ) {
    if (isInCurrentDepartment) {
      return ElevatedButton(
        onPressed: () => _confirmRemoveAssignment(teacher),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.red,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          elevation: 0,
        ),
        child: const Text(
          'Bỏ gán',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    } else if (isAssigned) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.slate200,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          teacher.departmentName ?? 'Đã gán',
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.slate400,
          ),
        ),
      );
    } else {
      return ElevatedButton(
        onPressed: _selectedDepartment != null
            ? () => _assignTeacher(teacher)
            : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          elevation: 0,
        ),
        child: const Text(
          'Gán',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }
  }

  void _assignTeacher(Teacher teacher) {
    if (_selectedDepartment == null) return;
    _teacherBloc.assignTeacherToDepartment(
      teacherId: teacher.id,
      departmentId: _selectedDepartment!.id,
    );
  }

  void _confirmRemoveAssignment(Teacher teacher) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận bỏ gán'),
        content: Text(
          'Bạn có chắc muốn bỏ gán giáo viên "${teacher.userId}" khỏi phòng ban "${_selectedDepartment?.name}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => AppNavigator.pop(),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () {
              _teacherBloc.removeTeacherFromDepartment(teacher.id);
              AppNavigator.pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.red,
            ),
            child: const Text('Bỏ gán'),
          ),
        ],
      ),
    );
  }

  Widget _buildCoursesTab() {
    return BlocBuilder<CourseBloc, CourseState>(
      bloc: _courseBloc,
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
          if (state.courses.isEmpty) {
            return const EmptyStateWidget(
              title: 'Chưa có học phần',
              subtitle: 'Danh sách học phần sẽ hiển thị tại đây',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: state.courses.length,
            itemBuilder: (context, index) {
              return _buildCourseCard(state.courses[index]);
            },
          );
        }
        if (state.requestStatus == RequestStatus.failed) {
          return _buildRetryWidget(
            state.message ?? 'Có lỗi xảy ra',
            () => _courseBloc.loadCourses(),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildCourseCard(Course course) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  course.courseName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.slate900,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.green100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  course.attendanceMode.shortLabel,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.green600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (course.courseCode != null) ...[
                const Icon(
                  Icons.tag,
                  size: 14,
                  color: AppColors.slate500,
                ),
                const SizedBox(width: 4),
                Text(
                  course.courseCode!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.slate500,
                  ),
                ),
                const SizedBox(width: 12),
              ],
              const Icon(
                Icons.group,
                size: 14,
                color: AppColors.slate500,
              ),
              const SizedBox(width: 4),
              Text(
                '${course.enrolledCount} học sinh',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.slate500,
                ),
              ),
            ],
          ),
          if (course.instructorName != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.person,
                  size: 14,
                  color: AppColors.slate500,
                ),
                const SizedBox(width: 4),
                Text(
                  'GV: ${course.instructorName}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.slate500,
                  ),
                ),
              ],
            ),
          ],
          if (course.roomName != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(
                  Icons.meeting_room,
                  size: 14,
                  color: AppColors.slate500,
                ),
                const SizedBox(width: 4),
                Text(
                  'Phòng: ${course.roomName}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.slate500,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRetryWidget(String message, VoidCallback onRetry) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            size: 48,
            color: AppColors.red,
          ),
          const SizedBox(height: 12),
          SelectableText.rich(
            TextSpan(
              text: message,
              style: const TextStyle(color: AppColors.red, fontSize: 14),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onRetry,
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
}
