import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:face_time_keeping/common/utils/alerts.dart';
import 'package:face_time_keeping/common/enums/request_status.dart';
import 'package:face_time_keeping/common/resources/app_colors.dart';
import 'package:face_time_keeping/common/resources/styles/text_styles.dart';
import 'package:face_time_keeping/data/remote/department_service.dart';
import 'package:face_time_keeping/data/remote/room_service.dart';
import 'package:face_time_keeping/data/remote/teacher_service.dart';
import 'package:face_time_keeping/di/injection.dart';
import 'package:face_time_keeping/entities/course.dart';
import 'package:face_time_keeping/entities/department.dart';
import 'package:face_time_keeping/entities/room.dart';
import 'package:face_time_keeping/entities/teacher.dart';
import 'package:face_time_keeping/pages/course/bloc/course_bloc.dart';
import 'package:face_time_keeping/data/remote/time_slot_service.dart';
import 'package:face_time_keeping/entities/time_slot.dart';
import 'package:face_time_keeping/route/navigator.dart';

class CourseFormPage extends StatelessWidget {
  final Course? course;

  const CourseFormPage({super.key, this.course});

  @override
  Widget build(BuildContext context) {
    final courseBloc = getIt<CourseBloc>();
    return BlocProvider.value(
      value: courseBloc,
      child: _CourseFormView(courseBloc: courseBloc, course: course),
    );
  }
}

class _CourseFormView extends StatefulWidget {
  final CourseBloc courseBloc;
  final Course? course;

  const _CourseFormView({required this.courseBloc, this.course});

  @override
  State<_CourseFormView> createState() => _CourseFormViewState();
}

class _CourseFormViewState extends State<_CourseFormView> {
  final _formKey = GlobalKey<FormState>();
  final _courseNameController = TextEditingController();
  final _courseCodeController = TextEditingController();
  final _startMinutesController = TextEditingController();
  final _endMinutesController = TextEditingController();

  AttendanceMode _selectedMode = AttendanceMode.preset;
  bool _isLoading = false;

  // Dropdown data
  List<Department> _departments = [];
  List<Teacher> _teachers = [];
  List<Teacher> _filteredTeachers = [];
  List<Room> _rooms = [];
  List<TimeSlot> _timeSlots = [];

  String? _selectedDepartmentId;
  int? _selectedTeacherId;
  String? _selectedRoomId;
  int? _selectedDayOfWeek;
  int? _selectedTimeSlotId;

  bool _loadingDepartments = false;
  bool _loadingTeachers = false;
  bool _loadingRooms = false;
  bool _loadingTimeSlots = false;

  bool get _isEditing => widget.course != null;

  @override
  void initState() {
    super.initState();
    if (widget.course != null) {
      _courseNameController.text = widget.course!.courseName;
      _courseCodeController.text = widget.course!.courseCode ?? '';
      _selectedMode = widget.course!.attendanceMode;
      _startMinutesController.text =
          widget.course!.customWindowStartMinutes.toString();
      _endMinutesController.text =
          widget.course!.customWindowEndMinutes.toString();
      _selectedDepartmentId = widget.course!.departmentId;
      _selectedRoomId = widget.course!.roomId;
      _selectedDayOfWeek = widget.course!.dayOfWeek;
      _selectedTimeSlotId = widget.course!.timeSlotId;
    } else {
      _startMinutesController.text = '0';
      _endMinutesController.text = '30';
    }
    _loadDepartments();
    _loadTeachers();
    _loadRooms();
    _loadTimeSlots();
  }

  Future<void> _loadDepartments() async {
    setState(() => _loadingDepartments = true);
    final result = await getIt<DepartmentService>().getDepartments();
    if (mounted) {
      setState(() {
        _departments = result.data ?? [];
        _loadingDepartments = false;
      });
    }
  }

  Future<void> _loadTeachers() async {
    setState(() => _loadingTeachers = true);
    final result = await getIt<TeacherService>().getTeachers(limit: 200);
    if (mounted) {
      setState(() {
        _teachers = result.data ?? [];
        _loadingTeachers = false;
        // Apply filter
        _updateFilteredTeachers();

        // Find matching teacher for edit mode
        if (widget.course?.teacherId != null) {
          _selectedTeacherId = widget.course!.teacherId;
        }
      });
    }
  }

  Future<void> _loadRooms() async {
    setState(() => _loadingRooms = true);
    final result = await getIt<RoomService>().getRooms(limit: 200);
    if (mounted) {
      setState(() {
        _rooms = result.data ?? [];
        _loadingRooms = false;
      });
    }
  }

  Future<void> _loadTimeSlots() async {
    setState(() => _loadingTimeSlots = true);
    final result = await getIt<TimeSlotService>().getTimeSlots();
    if (mounted) {
      setState(() {
        _timeSlots = result.data ?? [];
        _loadingTimeSlots = false;
      });
    }
  }

  @override
  void dispose() {
    _courseNameController.dispose();
    _courseCodeController.dispose();
    _startMinutesController.dispose();
    _endMinutesController.dispose();
    super.dispose();
  }

  void _onDepartmentChanged(String? deptId) {
    setState(() {
      _selectedDepartmentId = deptId;
      _selectedTeacherId = null; // Reset teacher when dept changes
      _updateFilteredTeachers();
    });
  }

  void _onTeacherChanged(int? id) {
    setState(() => _selectedTeacherId = id);
  }

  void _onRoomChanged(String? id) {
    setState(() => _selectedRoomId = id);
  }

  void _updateFilteredTeachers() {
    if (_selectedDepartmentId == null) {
      _filteredTeachers = [];
    } else {
      _filteredTeachers = _teachers
          .where((t) => t.departmentId == _selectedDepartmentId)
          .toList();
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if ((_selectedDayOfWeek == null) != (_selectedTimeSlotId == null)) {
      showTopAlert(
        context,
        title: 'Vui lòng chọn đầy đủ cả Thứ và Tiết học.',
        type: AlertType.error,
      );
      return;
    }

    if (_selectedMode == AttendanceMode.custom) {
      if (_selectedTimeSlotId == null) {
        showTopAlert(
          context,
          title:
              'Chế độ Tự thiết lập yêu cầu chọn Tiết học để xác định giới hạn.',
          type: AlertType.error,
        );
        return;
      }
      final startMin = int.tryParse(_startMinutesController.text) ?? 0;
      final endMin = int.tryParse(_endMinutesController.text) ?? 0;
      // Find selected time slot and compute its duration from "HH:mm" strings
      final slot = _timeSlots.firstWhere(
        (s) => s.id == _selectedTimeSlotId,
        orElse: () => _timeSlots.first,
      );
      int _parseMinutes(String t) {
        final parts = t.split(':');
        return int.parse(parts[0]) * 60 + int.parse(parts[1]);
      }

      final slotDuration =
          _parseMinutes(slot.endTime) - _parseMinutes(slot.startTime);
      if (endMin <= startMin) {
        showTopAlert(
          context,
          title: 'Thời gian Kết thúc phải lớn hơn thời gian Bắt đầu.',
          type: AlertType.error,
        );
        return;
      }
      if (endMin > slotDuration) {
        showTopAlert(
          context,
          title:
              'Thời gian kết thúc ($endMin phút) vượt quá thời lượng tiết học ($slotDuration phút).',
          type: AlertType.error,
        );
        return;
      }
    }

    setState(() => _isLoading = true);

    final startMinutes = int.tryParse(_startMinutesController.text) ?? 0;
    final endMinutes = int.tryParse(_endMinutesController.text) ?? 30;

    if (_isEditing) {
      await widget.courseBloc.updateCourse(
        id: widget.course!.id,
        courseName: _courseNameController.text.trim(),
        courseCode: _courseCodeController.text.trim().isNotEmpty
            ? _courseCodeController.text.trim()
            : null,
        departmentId: _selectedDepartmentId,
        teacherId: _selectedTeacherId,
        roomId: _selectedRoomId,
        attendanceMode: _selectedMode,
        customWindowStartMinutes: startMinutes,
        customWindowEndMinutes: endMinutes,
        dayOfWeek: _selectedDayOfWeek,
        timeSlotId: _selectedTimeSlotId,
      );
    } else {
      await widget.courseBloc.createCourse(
        courseName: _courseNameController.text.trim(),
        courseCode: _courseCodeController.text.trim().isNotEmpty
            ? _courseCodeController.text.trim()
            : null,
        departmentId: _selectedDepartmentId,
        teacherId: _selectedTeacherId,
        roomId: _selectedRoomId,
        attendanceMode: _selectedMode,
        customWindowStartMinutes: startMinutes,
        customWindowEndMinutes: endMinutes,
        dayOfWeek: _selectedDayOfWeek,
        timeSlotId: _selectedTimeSlotId,
      );
    }

    if (mounted) {
      if (widget.courseBloc.state.requestStatus == RequestStatus.success) {
        showTopAlert(
          context,
          title: _isEditing
              ? 'Cập nhật học phần thành công!'
              : 'Tạo học phần thành công!',
          type: AlertType.success,
        );
        await Future.delayed(const Duration(milliseconds: 300));
        if (mounted) {
          setState(() => _isLoading = false);
          AppNavigator.pop(true);
        }
      } else {
        setState(() => _isLoading = false);
        final errorMessage = widget.courseBloc.state.message ??
            'Có lỗi xảy ra, vui lòng thử lại!';
        final isScheduleConflict = errorMessage.contains('đã có học phần') ||
            errorMessage.contains('Phòng học đã được dùng');

        // Conflict errors are already surfaced by the shared course list listener.
        // Skip top alert here to avoid duplicated notifications.
        if (!isScheduleConflict) {
          showTopAlert(
            context,
            title: errorMessage,
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
        title: Text(
          _isEditing ? 'SỬA HỌC PHẦN' : 'TẠO HỌC PHẦN',
          style: const TextStyle(
            color: AppColors.slate900,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        automaticallyImplyLeading: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.slate900),
          onPressed: () => AppNavigator.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildBasicInfoCard(),
              const SizedBox(height: 16),
              _buildAssignmentCard(),
              const SizedBox(height: 16),
              _buildAttendanceModeCard(),
              const SizedBox(height: 24),
              _buildSubmitButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBasicInfoCard() {
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
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline,
                  color: AppColors.blue600, size: 20),
              const SizedBox(width: 8),
              Text(
                'Thông tin cơ bản',
                style: TextStyles.blackSmallBold.copyWith(fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildTextField(
            controller: _courseNameController,
            label: 'Tên học phần',
            hint: 'Nhập tên học phần',
            isRequired: true,
            icon: Icons.school,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _courseCodeController,
            label: 'Mã học phần',
            hint: 'Nhập mã học phần (tùy chọn)',
            icon: Icons.qr_code,
          ),
        ],
      ),
    );
  }

  Widget _buildAssignmentCard() {
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
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.assignment_ind,
                  color: AppColors.blue600, size: 20),
              const SizedBox(width: 8),
              Text(
                'Phân công',
                style: TextStyles.blackSmallBold.copyWith(fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildDropdownField(
            label: 'Phòng ban',
            icon: Icons.business,
            hint: 'Chọn phòng ban',
            value: _selectedDepartmentId,
            items: _departments
                .map((d) => DropdownMenuItem<String>(
                      value: d.id,
                      child: Text(d.name, overflow: TextOverflow.ellipsis),
                    ))
                .toList(),
            onChanged: _loadingDepartments ? null : _onDepartmentChanged,
            isLoading: _loadingDepartments,
          ),
          if (_selectedDepartmentId != null) ...[
            const SizedBox(height: 16),
            _buildDropdownField<int>(
              label: 'Giảng viên',
              icon: Icons.person,
              hint: 'Chọn giảng viên',
              value: _selectedTeacherId,
              items: _filteredTeachers
                  .map((t) => DropdownMenuItem<int>(
                        value: t.id,
                        child: Text(
                          '${t.teacherId ?? ''} - ${t.userFullName ?? 'GV #${t.id}'}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ))
                  .toList(),
              onChanged: _loadingTeachers ? null : _onTeacherChanged,
              isLoading: _loadingTeachers,
            ),
          ],
          const SizedBox(height: 16),
          _buildDropdownField<String>(
            label: 'Phòng học',
            icon: Icons.meeting_room,
            hint: 'Chọn phòng học',
            value: _selectedRoomId,
            items: _rooms
                .map((r) => DropdownMenuItem<String>(
                      value: r.id,
                      child:
                          Text(r.displayName, overflow: TextOverflow.ellipsis),
                    ))
                .toList(),
            onChanged: _loadingRooms ? null : _onRoomChanged,
            isLoading: _loadingRooms,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildDropdownField<int>(
                  label: 'Thứ',
                  icon: Icons.calendar_today,
                  hint: 'Chọn thứ',
                  value: _selectedDayOfWeek,
                  items: _daysOfWeek
                      .map((d) => DropdownMenuItem<int>(
                            value: d['value'] as int,
                            child: Text(d['label'] as String,
                                overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: (val) => setState(() => _selectedDayOfWeek = val),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDropdownField<int>(
                  label: 'Tiết học',
                  icon: Icons.access_time,
                  hint: 'Chọn tiết',
                  value: _selectedTimeSlotId,
                  items: _timeSlots
                      .map((s) => DropdownMenuItem<int>(
                            value: s.id,
                            child: Text('Tiết ${s.periodNumber}',
                                overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: (val) => setState(() {
                    _selectedTimeSlotId = val;
                    // If time slot cleared while custom mode is active → fallback to preset
                    if (val == null && _selectedMode == AttendanceMode.custom) {
                      _selectedMode = AttendanceMode.preset;
                    }
                  }),
                  isLoading: _loadingTimeSlots,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static const _daysOfWeek = [
    {'value': 1, 'label': 'Thứ Hai'},
    {'value': 2, 'label': 'Thứ Ba'},
    {'value': 3, 'label': 'Thứ Tư'},
    {'value': 4, 'label': 'Thứ Năm'},
    {'value': 5, 'label': 'Thứ Sáu'},
    {'value': 6, 'label': 'Thứ Bảy'},
    {'value': 7, 'label': 'Chủ Nhật'},
  ];

  Widget _buildDropdownField<T>({
    required String label,
    required IconData icon,
    required String hint,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?)? onChanged,
    bool isLoading = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.slate900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.backgroundLight,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.slate300),
          ),
          child: InputDecorator(
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: AppColors.slate500, size: 20),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
            child: isLoading
                ? const Row(
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 8),
                      Text('Đang tải...',
                          style: TextStyle(color: AppColors.slate500)),
                    ],
                  )
                : DropdownButtonHideUnderline(
                    child: DropdownButton<T>(
                      isExpanded: true,
                      value: value,
                      hint: Text(hint,
                          style: const TextStyle(color: AppColors.slate400)),
                      items: items,
                      onChanged: onChanged,
                      dropdownColor: Colors.white,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildAttendanceModeCard() {
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
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.schedule, color: AppColors.blue600, size: 20),
              const SizedBox(width: 8),
              Text(
                'Chế độ điểm danh',
                style: TextStyles.blackSmallBold.copyWith(fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Chọn cách hệ thống quản lý thời gian điểm danh cho học phần.',
            style: const TextStyle(fontSize: 13, color: AppColors.slate500),
          ),
          const SizedBox(height: 16),
          _buildAttendanceModeOption(
            mode: AttendanceMode.preset,
            title: 'Cố định',
            description: 'Tự động mở/đóng trong khoảng thời gian tiết học',
            icon: Icons.timer,
            color: AppColors.blue600,
          ),
          const SizedBox(height: 12),
          _buildAttendanceModeOption(
            mode: AttendanceMode.flexible,
            title: 'Linh hoạt',
            description:
                'Giáo viên được phép đóng mở thủ công khi tiết đang diễn ra',
            icon: Icons.all_inclusive,
            color: AppColors.purple600,
          ),
          const SizedBox(height: 12),
          _buildAttendanceModeOption(
            mode: AttendanceMode.custom,
            title: 'Tự thiết lập',
            description: ' Tự động mở/đóng trong khoảng thời gian của tiết học',
            icon: Icons.tune,
            color: AppColors.teal600,
            disabled: _selectedTimeSlotId == null,
            disabledHint: 'Vui lòng chọn Tiết học trước',
          ),
          if (_selectedMode == AttendanceMode.custom) ...[
            const SizedBox(height: 16),
            _buildCustomTimeInputs(),
          ],
        ],
      ),
    );
  }

  Widget _buildAttendanceModeOption({
    required AttendanceMode mode,
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    bool disabled = false,
    String? disabledHint,
  }) {
    final isSelected = _selectedMode == mode;
    final effectiveColor = disabled ? AppColors.slate400 : color;

    Widget option = GestureDetector(
      onTap: disabled
          ? () {
              showTopAlert(
                context,
                title: disabledHint ?? 'Không khả dụng',
                type: AlertType.error,
              );
            }
          : () => setState(() => _selectedMode = mode),
      child: Opacity(
        opacity: disabled ? 0.5 : 1.0,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: disabled
                ? AppColors.backgroundLight
                : isSelected
                    ? effectiveColor.withOpacity(0.1)
                    : AppColors.backgroundLight,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color:
                  isSelected && !disabled ? effectiveColor : AppColors.slate300,
              width: isSelected && !disabled ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isSelected && !disabled
                      ? effectiveColor
                      : AppColors.slate200,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon,
                    color: isSelected && !disabled
                        ? Colors.white
                        : AppColors.slate500,
                    size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: disabled
                            ? AppColors.slate400
                            : isSelected
                                ? effectiveColor
                                : AppColors.slate900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      disabled ? (disabledHint ?? description) : description,
                      style: TextStyle(
                        fontSize: 12,
                        color:
                            disabled ? AppColors.slate400 : AppColors.slate500,
                        fontStyle:
                            disabled ? FontStyle.italic : FontStyle.normal,
                      ),
                    ),
                  ],
                ),
              ),
              Radio<AttendanceMode>(
                value: mode,
                groupValue: disabled ? null : _selectedMode,
                onChanged: disabled
                    ? null
                    : (value) {
                        if (value != null)
                          setState(() => _selectedMode = value);
                      },
                activeColor: effectiveColor,
              ),
            ],
          ),
        ),
      ),
    );

    return option;
  }

  Widget _buildCustomTimeInputs() {
    // Compute live preview from selected time slot + current field values
    String _previewText() {
      if (_selectedTimeSlotId == null || _timeSlots.isEmpty) {
        return 'Chọn Tiết học để xem khoảng thời gian';
      }
      final slot = _timeSlots.firstWhere(
        (s) => s.id == _selectedTimeSlotId,
        orElse: () => _timeSlots.first,
      );
      int parseMinutes(String t) {
        final parts = t.split(':');
        if (parts.length < 2) return 0;
        return int.parse(parts[0]) * 60 + int.parse(parts[1]);
      }

      String formatMinutes(int totalMinutes) {
        final h = totalMinutes ~/ 60;
        final m = totalMinutes % 60;
        return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
      }

      final slotStartMin = parseMinutes(slot.startTime);
      final slotEndMin = parseMinutes(slot.endTime);
      final slotDuration = slotEndMin - slotStartMin;

      final startMin = int.tryParse(_startMinutesController.text) ?? 0;
      final endMin = int.tryParse(_endMinutesController.text) ?? 0;

      final openMin = slotStartMin + startMin;
      final closeMin = (slotStartMin + endMin).clamp(openMin, slotEndMin);

      final openStr = formatMinutes(openMin);
      final closeStr = formatMinutes(closeMin);

      if (endMin <= startMin) {
        return '⚠️ Kết thúc ($endMin) phải sau Bắt đầu ($startMin)';
      }
      if (endMin > slotDuration) {
        return '⚠️ Kết thúc ($endMin phút) vượt thời lượng tiết ($slotDuration phút) — Chốt: $closeStr (bị cắt)';
      }
      return '🕐 Mở: $openStr  →  Đóng: $closeStr  (trong tiết ${slot.startTime}–${slot.endTime})';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.teal50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Thiết lập thời gian (phút)',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.teal600,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildNumberField(
                  controller: _startMinutesController,
                  label: 'Bắt đầu (phút)',
                  color: AppColors.teal600,
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildNumberField(
                  controller: _endMinutesController,
                  label: 'Kết thúc (phút)',
                  color: AppColors.teal600,
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.teal600.withOpacity(0.4)),
            ),
            child: Text(
              _previewText(),
              style: TextStyle(
                fontSize: 13,
                color: (int.tryParse(_startMinutesController.text) ?? 0) >=
                            (int.tryParse(_endMinutesController.text) ?? 0) ||
                        (int.tryParse(_endMinutesController.text) ?? 0) >
                            (_selectedTimeSlotId != null && _timeSlots.isNotEmpty
                                ? () {
                                    final s = _timeSlots.firstWhere(
                                        (s) => s.id == _selectedTimeSlotId,
                                        orElse: () => _timeSlots.first);
                                    int p(String t) {
                                      final parts = t.split(':');
                                      return int.parse(parts[0]) * 60 +
                                          int.parse(parts[1]);
                                    }

                                    return p(s.endTime) - p(s.startTime);
                                  }()
                                : 9999)
                    ? AppColors.red600
                    : AppColors.teal600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool isRequired = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.slate900,
              ),
            ),
            if (isRequired)
              const Text(
                ' *',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.red600,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: AppColors.slate400),
            prefixIcon: Icon(icon, color: AppColors.slate500, size: 20),
            filled: true,
            fillColor: AppColors.backgroundLight,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.slate300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.slate300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.red600),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          validator: isRequired
              ? (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Vui lòng nhập $label';
                  }
                  return null;
                }
              : null,
        ),
      ],
    );
  }

  Widget _buildNumberField({
    required TextEditingController controller,
    required String label,
    required Color color,
    void Function(String)? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.slate900,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          onChanged: onChanged,
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
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: color.withOpacity(0.5)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: color.withOpacity(0.5)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: color, width: 2),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Nhập số phút';
            }
            final minutes = int.tryParse(value);
            if (minutes == null || minutes < 0 || minutes > 120) {
              return '0 - 120';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return ElevatedButton(
      onPressed: _isLoading ? null : _submit,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        disabledBackgroundColor: AppColors.slate300,
      ),
      child: _isLoading
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Text(
              _isEditing ? 'Cập nhật' : 'Tạo học phần',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
    );
  }
}
