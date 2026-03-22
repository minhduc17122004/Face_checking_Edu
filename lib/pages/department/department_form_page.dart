import 'package:flutter/material.dart';
import 'package:face_time_keeping/common/resources/app_colors.dart';
import 'package:face_time_keeping/common/resources/styles/text_styles.dart';
import 'package:face_time_keeping/common/enums/request_status.dart';
import 'package:face_time_keeping/common/utils/alerts.dart';
import 'package:face_time_keeping/di/injection.dart';
import 'package:face_time_keeping/entities/department.dart';
import 'package:face_time_keeping/pages/department/bloc/department_bloc.dart';
import 'package:face_time_keeping/route/navigator.dart';

class DepartmentFormPage extends StatefulWidget {
  final Department? department;

  const DepartmentFormPage({super.key, this.department});

  @override
  State<DepartmentFormPage> createState() => _DepartmentFormPageState();
}

class _DepartmentFormPageState extends State<DepartmentFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _codeController;
  late final TextEditingController _nameController;
  bool _isLoading = false;

  bool get _isEditing => widget.department != null;

  @override
  void initState() {
    super.initState();
    _codeController = TextEditingController(text: widget.department?.code);
    _nameController = TextEditingController(text: widget.department?.name);
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit(BuildContext context) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final bloc = getIt<DepartmentBloc>();
    if (_isEditing) {
      await bloc.updateDepartment(
        id: widget.department!.id,
        code: _codeController.text.trim(),
        name: _nameController.text.trim(),
      );
    } else {
      await bloc.createDepartment(
        code: _codeController.text.trim(),
        name: _nameController.text.trim(),
      );
    }

    if (mounted) {
      if (bloc.state.requestStatus == RequestStatus.success) {
        showTopAlert(
          context,
          title: _isEditing ? 'Cập nhật phòng ban thành công!' : 'Tạo phòng ban thành công!',
          type: AlertType.success,
        );
        await Future.delayed(const Duration(milliseconds: 300));
        if (mounted) {
          setState(() => _isLoading = false);
          AppNavigator.pop(true);
        }
      } else {
        setState(() => _isLoading = false);
        showTopAlert(
          context,
          title: bloc.state.message ?? 'Có lỗi xảy ra, vui lòng thử lại!',
          type: AlertType.error,
        );
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
          _isEditing ? 'SỬA PHÒNG BAN' : 'THÊM PHÒNG BAN',
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
      body: Form(
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
                  Text(
                    'Thông tin phòng ban',
                    style: TextStyles.blackNormalBold.copyWith(
                      fontSize: 16,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _codeController,
                    label: 'Mã phòng ban',
                    hint: 'VD: KHOA_CNTT',
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Vui lòng nhập mã phòng ban';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _nameController,
                    label: 'Tên phòng ban',
                    hint: 'VD: Khoa Công nghệ thông tin',
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Vui lòng nhập tên phòng ban';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading ? null : () => _submit(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : Text(
                        _isEditing ? 'Lưu thay đổi' : 'Tạo phòng ban',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
              ),
            ),
          ],
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
}
