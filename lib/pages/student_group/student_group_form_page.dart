import 'package:face_time_keeping/common/enums/request_status.dart';
import 'package:face_time_keeping/common/resources/index.dart';
import 'package:face_time_keeping/common/utils/alerts.dart';
import 'package:face_time_keeping/di/injection.dart';
import 'package:face_time_keeping/entities/student_group.dart';
import 'package:face_time_keeping/pages/student_group/bloc/student_group_cubit.dart';
import 'package:face_time_keeping/pages/student_group/bloc/student_group_state.dart';
import 'package:face_time_keeping/route/navigator.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class StudentGroupFormPage extends StatelessWidget {
  const StudentGroupFormPage({super.key, this.studentGroup});

  final StudentGroup? studentGroup;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => getIt<StudentGroupCubit>()
        ..loadFormData(departmentId: studentGroup?.departmentId),
      child: StudentGroupFormView(studentGroup: studentGroup),
    );
  }
}

class StudentGroupFormView extends StatefulWidget {
  const StudentGroupFormView({super.key, this.studentGroup});

  final StudentGroup? studentGroup;

  @override
  State<StudentGroupFormView> createState() => _StudentGroupFormViewState();
}

class _StudentGroupFormViewState extends State<StudentGroupFormView> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;

  String? _selectedDepartmentId;
  String? _selectedAdvisorId;

  bool get _isEditing => widget.studentGroup != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.studentGroup?.name);
    _selectedDepartmentId = widget.studentGroup?.departmentId;
    _selectedAdvisorId = widget.studentGroup?.advisorId;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit(BuildContext context) async {
    if (!_formKey.currentState!.validate()) return;

    final cubit = context.read<StudentGroupCubit>();
    bool success;

    if (_isEditing) {
      success = await cubit.updateStudentGroup(
        widget.studentGroup!.id,
        name: _nameController.text.trim(),
        departmentId: _selectedDepartmentId,
        advisorId: _selectedAdvisorId,
      );
    } else {
      success = await cubit.createStudentGroup(
        name: _nameController.text.trim(),
        departmentId: _selectedDepartmentId,
        advisorId: _selectedAdvisorId,
      );
    }

    if (context.mounted) {
      if (success) {
        showTopAlert(
          context,
          title: _isEditing
              ? 'Cập nhật lớp học thành công!'
              : 'Thêm lớp học thành công!',
          type: AlertType.success,
        );
        await Future.delayed(const Duration(milliseconds: 300));
        if (context.mounted) {
          AppNavigator.pop(true);
        }
      } else {
        showTopAlert(
          context,
          title: cubit.state.message ??
              (_isEditing ? 'Cập nhật thất bại' : 'Thêm mới thất bại'),
          type: AlertType.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<StudentGroupCubit, StudentGroupState>(
      listenWhen: (previous, current) => previous.teachers != current.teachers,
      listener: (context, state) {
        // If current advisor is not in the new teacher list, clear it
        if (_selectedAdvisorId != null &&
            !state.teachers.any((t) => t.userId == _selectedAdvisorId)) {
          setState(() {
            _selectedAdvisorId = null;
          });
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.backgroundLight,
        appBar: AppBar(
          centerTitle: true,
          title: Text(
            _isEditing ? 'SỬA LỚP HỌC' : 'THÊM LỚP HỌC',
            style: const TextStyle(
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
        body: BlocBuilder<StudentGroupCubit, StudentGroupState>(
          builder: (context, state) {
            final isLoadingData = state.requestStatus == RequestStatus.requesting &&
                state.departments.isEmpty;

            if (isLoadingData) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              );
            }

            return Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                   Container(
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
                        const Text(
                          'Thông tin lớp học',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _nameController,
                          label: 'Tên lớp',
                          hint: '48K21.1',
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Vui lòng nhập tên lớp';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildDropdown(
                          label: 'Khoa',
                          value: _selectedDepartmentId,
                          items: state.departments
                              .map((d) => DropdownMenuItem(
                                    value: d.id,
                                    child: Text(d.name),
                                  ))
                              .toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedDepartmentId = value;
                            });
                            context
                                .read<StudentGroupCubit>()
                                .loadTeachers(value);
                          },
                          hint: 'Chọn khoa',
                        ),
                        const SizedBox(height: 16),
                        _buildDropdown(
                          label: 'Giáo viên chủ nhiệm',
                          value: _selectedAdvisorId,
                          items: state.teachers
                              .where((t) => t.userId.isNotEmpty)
                              .map((t) => DropdownMenuItem(
                                    value: t.userId,
                                    child: Text(t.userFullName ??
                                        t.teacherId ??
                                        t.userId),
                                  ))
                              .toList(),
                          onChanged: (value) {
                            setState(() => _selectedAdvisorId = value);
                          },
                          hint: 'Chọn giáo viên',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: state.requestStatus == RequestStatus.requesting
                          ? null
                          : () => _submit(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: state.requestStatus == RequestStatus.requesting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation(Colors.white),
                              ),
                            )
                          : Text(
                              _isEditing ? 'Lưu thay đổi' : 'Tạo lớp học',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    int maxLines = 1,
    bool enabled = true,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: AppColors.slate900,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          enabled: enabled,
          maxLines: maxLines,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: enabled ? Colors.white : Colors.grey[100],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.red),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
          validator: validator,
        ),
      ],
    );
  }

  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<DropdownMenuItem<String>> items,
    required void Function(String?) onChanged,
    required String hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: AppColors.slate900,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              items: [
                DropdownMenuItem<String>(
                  value: null,
                  child: Text(
                    hint,
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                ),
                ...items,
              ],
              onChanged: onChanged,
              isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down),
              style: const TextStyle(
                color: AppColors.slate900,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }
}