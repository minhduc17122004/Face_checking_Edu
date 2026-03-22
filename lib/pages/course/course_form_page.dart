import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:face_time_keeping/common/enums/request_status.dart';
import 'package:face_time_keeping/common/resources/app_colors.dart';
import 'package:face_time_keeping/common/resources/styles/text_styles.dart';
import 'package:face_time_keeping/di/injection.dart';
import 'package:face_time_keeping/entities/course.dart';
import 'package:face_time_keeping/pages/course/bloc/course_bloc.dart';
import 'package:face_time_keeping/pages/course/bloc/course_state.dart';
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
  final _subjectController = TextEditingController();
  final _beforeMinutesController = TextEditingController();
  final _afterMinutesController = TextEditingController();

  AttendanceMode _selectedMode = AttendanceMode.preset;
  bool _isLoading = false;

  bool get _isEditing => widget.course != null;

  @override
  void initState() {
    super.initState();
    if (widget.course != null) {
      _courseNameController.text = widget.course!.courseName;
      _courseCodeController.text = widget.course!.courseCode ?? '';
      _subjectController.text = widget.course!.subject ?? '';
      _selectedMode = widget.course!.attendanceMode;
      _beforeMinutesController.text =
          widget.course!.attendanceBeforeMinutes.toString();
      _afterMinutesController.text =
          widget.course!.attendanceAfterMinutes.toString();
    } else {
      _beforeMinutesController.text = '30';
      _afterMinutesController.text = '30';
    }
  }

  @override
  void dispose() {
    _courseNameController.dispose();
    _courseCodeController.dispose();
    _subjectController.dispose();
    _beforeMinutesController.dispose();
    _afterMinutesController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final beforeMinutes =
        int.tryParse(_beforeMinutesController.text) ?? 30;
    final afterMinutes = int.tryParse(_afterMinutesController.text) ?? 30;

    widget.courseBloc.createCourse(
          courseName: _courseNameController.text.trim(),
          courseCode: _courseCodeController.text.trim().isNotEmpty
              ? _courseCodeController.text.trim()
              : null,
          subject: _subjectController.text.trim().isNotEmpty
              ? _subjectController.text.trim()
              : null,
          attendanceMode: _selectedMode,
          attendanceBeforeMinutes: beforeMinutes,
          attendanceAfterMinutes: afterMinutes,
        );
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
      body: BlocListener<CourseBloc, CourseState>(
        listener: (context, state) {
          if (state.requestStatus == RequestStatus.requesting) {
            setState(() => _isLoading = true);
          } else if (state.requestStatus == RequestStatus.success &&
              state.message != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  _isEditing
                      ? 'Đã cập nhật học phần'
                      : 'Đã tạo học phần mới',
                ),
                backgroundColor: AppColors.green600,
              ),
            );
            AppNavigator.pop();
          } else if (state.requestStatus == RequestStatus.failed) {
            setState(() => _isLoading = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: SelectableText(state.message ?? 'Có lỗi xảy ra'),
                backgroundColor: AppColors.red600,
              ),
            );
          }
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildBasicInfoCard(),
                const SizedBox(height: 16),
                _buildAttendanceModeCard(),
                const SizedBox(height: 24),
                _buildSubmitButton(),
              ],
            ),
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
          const SizedBox(height: 16),
          _buildTextField(
            controller: _subjectController,
            label: 'Môn học',
            hint: 'Nhập tên môn học (tùy chọn)',
            icon: Icons.menu_book,
          ),
        ],
      ),
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
          const SizedBox(height: 20),
          _buildAttendanceModeOption(
            mode: AttendanceMode.preset,
            title: 'Đặt trước',
            description: '30 phút trước - 30 phút sau giờ học',
            icon: Icons.timer,
            color: AppColors.blue600,
          ),
          const SizedBox(height: 12),
          _buildAttendanceModeOption(
            mode: AttendanceMode.flexible,
            title: 'Linh hoạt',
            description: 'Luôn cho phép điểm danh (không giới hạn)',
            icon: Icons.all_inclusive,
            color: AppColors.purple600,
          ),
          const SizedBox(height: 12),
          _buildAttendanceModeOption(
            mode: AttendanceMode.custom,
            title: 'Tùy chỉnh',
            description: 'Tự thiết lập thời gian',
            icon: Icons.tune,
            color: AppColors.teal600,
          ),
          if (_selectedMode == AttendanceMode.custom) ...[
            const SizedBox(height: 20),
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
  }) {
    final isSelected = _selectedMode == mode;

    return GestureDetector(
      onTap: () => setState(() => _selectedMode = mode),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : AppColors.backgroundLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : AppColors.slate300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isSelected ? color : AppColors.slate200,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: isSelected ? Colors.white : AppColors.slate500, size: 20),
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
                      color: isSelected ? color : AppColors.slate900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.slate500,
                    ),
                  ),
                ],
              ),
            ),
            Radio<AttendanceMode>(
              value: mode,
              groupValue: _selectedMode,
              onChanged: (value) {
                if (value != null) setState(() => _selectedMode = value);
              },
              activeColor: color,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomTimeInputs() {
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
                  controller: _beforeMinutesController,
                  label: 'Trước giờ học',
                  color: AppColors.teal600,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildNumberField(
                  controller: _afterMinutesController,
                  label: 'Sau giờ học',
                  color: AppColors.teal600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Khoảng: 0 - 120 phút',
            style: TextStyles.greyExtraSmallRegular.copyWith(
              color: AppColors.slate500,
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
