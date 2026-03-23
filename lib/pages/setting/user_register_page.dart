import 'package:face_time_keeping/common/api_client/api_client.dart';
import 'package:face_time_keeping/common/api_client/data_state.dart';
import 'package:face_time_keeping/common/resources/app_colors.dart';
import 'package:face_time_keeping/common/resources/styles/text_styles.dart';
import 'package:face_time_keeping/data/models/register_user_request.dart';
import 'package:face_time_keeping/data/remote/api_endpoint.dart';
import 'package:face_time_keeping/di/injection.dart';
import 'package:face_time_keeping/entities/department.dart';
import 'package:face_time_keeping/pages/setting/cubit/setting/setting_cubit.dart';
import 'package:face_time_keeping/pages/widgets/default_app_bar.dart';
import 'package:flutter/material.dart';

class UserRegisterPage extends StatefulWidget {
  const UserRegisterPage({Key? key}) : super(key: key);

  @override
  State<UserRegisterPage> createState() => _UserRegisterPageState();
}

class _UserRegisterPageState extends State<UserRegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _pinController = TextEditingController();

  bool _isLoading = false;
  String _selectedRole = 'student';

  // For remote selection
  bool _isLoadingData = false;
  List<Department> _departments = [];
  List<Map<String, dynamic>> _studentGroups = [];

  Department? _selectedDepartment;
  Map<String, dynamic>? _selectedStudentGroup;

  @override
  void initState() {
    super.initState();
    _fetchSelectionData();
  }

  Future<void> _fetchSelectionData() async {
    setState(() => _isLoadingData = true);
    try {
      final apiClient = getIt<ApiClient>();

      // Load departments
      final deptResponse = await apiClient.get(
        path: '${ApiEndpoint.departments}?skip=0&limit=500',
      );
      if (deptResponse.isSuccess() && deptResponse.data != null) {
        final items = (deptResponse.data['items'] as List?) ?? const [];
        _departments = items.map((e) => Department.fromJson(e)).toList();
      }

      // Load student groups (lớp)
      final groupResponse = await apiClient.get(
        path: '${ApiEndpoint.studentGroups}?skip=0&limit=500',
      );
      if (groupResponse.isSuccess() && groupResponse.data != null) {
        final items = (groupResponse.data['items'] as List?) ?? const [];
        _studentGroups = List<Map<String, dynamic>>.from(items);
      }
    } catch (e) {
      debugPrint('Lỗi khi tải danh sách phòng ban / lớp: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingData = false);
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _fullNameController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  String _getPinLabel() {
    return _selectedRole == 'student' ? 'Mã sinh viên' : 'Mã giáo viên';
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    // Check if role-specific dropdown value is selected
    if (_selectedRole == 'student' && _selectedStudentGroup == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Vui lòng chọn Lớp'), backgroundColor: AppColors.red),
      );
      return;
    }
    if (_selectedRole == 'teacher' && _selectedDepartment == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Vui lòng chọn Phòng ban'),
            backgroundColor: AppColors.red),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final request = RegisterUserRequest(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        fullName: _fullNameController.text.trim(),
        role: _selectedRole,
        pin: _pinController.text.trim(),
        jobTitle: _selectedRole == 'student'
            ? _selectedStudentGroup!['code'].toString()
            : _selectedDepartment!.id,
      );

      final settingCubit = getIt<SettingCubit>();
      final result = await settingCubit.registerUser(request);

      if (!mounted) return;

      if (result.isSuccess) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Text(
                    'Đăng ký ${_selectedRole == 'student' ? 'học sinh' : 'giáo viên'} thành công!'),
              ],
            ),
            backgroundColor: AppColors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        FocusScope.of(context).unfocus();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(child: Text(result.error ?? 'Lỗi đăng ký')),
              ],
            ),
            backgroundColor: AppColors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi: $e'),
          backgroundColor: AppColors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: DefaultAppBar(
        titleText: 'Đăng ký người dùng',
      ),
      body: _isLoadingData
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Gợi ý cho Admin
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: AppColors.purple.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppColors.purple.withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline,
                              color: AppColors.purple, size: 20),
                          const SizedBox(width: 12),
                          Text(
                            'Chức năng cấp tài khoản dành cho Admin',
                            style: TextStyles.blackNormalBold.copyWith(
                              color: AppColors.purple,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Role selector
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Loại tài khoản',
                            style: TextStyles.blackNormalBold,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _RoleOption(
                                  label: 'Học sinh',
                                  icon: Icons.school,
                                  isSelected: _selectedRole == 'student',
                                  onTap: () => setState(() {
                                    _selectedRole = 'student';
                                  }),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _RoleOption(
                                  label: 'Giáo viên',
                                  icon: Icons.person,
                                  isSelected: _selectedRole == 'teacher',
                                  onTap: () => setState(() {
                                    _selectedRole = 'teacher';
                                  }),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Form Fields
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          _buildTextField(
                            controller: _fullNameController,
                            label: 'Họ và tên',
                            icon: Icons.badge_outlined,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Vui lòng nhập họ và tên';
                              }
                              if (value.trim().length < 2) {
                                return 'Tên phải có ít nhất 2 ký tự';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          _buildTextField(
                            controller: _pinController,
                            label: _getPinLabel(),
                            icon: Icons.pin_outlined,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Vui lòng nhập ${_getPinLabel().toLowerCase()}';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Select Department or StudentGroup Based on Role
                          if (_selectedRole == 'teacher')
                            DropdownButtonFormField<Department>(
                              value: _selectedDepartment,
                              decoration: InputDecoration(
                                labelText: 'Phòng ban',
                                labelStyle:
                                    TextStyles.blackNormalRegular.copyWith(
                                  color: AppColors.gray200,
                                  fontSize: 13,
                                ),
                                prefixIcon: const Icon(Icons.business_outlined,
                                    color: AppColors.blue600),
                                filled: true,
                                fillColor: AppColors.blue50.withOpacity(0.5),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                      color: AppColors.blue.withOpacity(0.2)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                      color: AppColors.blue.withOpacity(0.2)),
                                ),
                              ),
                              items: _departments.map((dept) {
                                return DropdownMenuItem<Department>(
                                  value: dept,
                                  child: Text(dept.name),
                                );
                              }).toList(),
                              onChanged: (val) {
                                setState(() {
                                  _selectedDepartment = val;
                                });
                              },
                            ),

                          if (_selectedRole == 'student')
                            DropdownButtonFormField<Map<String, dynamic>>(
                              value: _selectedStudentGroup,
                              decoration: InputDecoration(
                                labelText: 'Lớp',
                                labelStyle:
                                    TextStyles.blackNormalRegular.copyWith(
                                  color: AppColors.gray200,
                                  fontSize: 13,
                                ),
                                prefixIcon: const Icon(Icons.class_outlined,
                                    color: AppColors.blue600),
                                filled: true,
                                fillColor: AppColors.blue50.withOpacity(0.5),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                      color: AppColors.blue.withOpacity(0.2)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                      color: AppColors.blue.withOpacity(0.2)),
                                ),
                              ),
                              items: _studentGroups.map((group) {
                                return DropdownMenuItem<Map<String, dynamic>>(
                                  value: group,
                                  child: Text(
                                      '${group['name'] ?? group['code']}'),
                                );
                              }).toList(),
                              onChanged: (val) {
                                setState(() {
                                  _selectedStudentGroup = val;
                                });
                              },
                            ),

                          const SizedBox(height: 24),
                          const Divider(),
                          const SizedBox(height: 12),
                          Text(
                            'Tài khoản đăng nhập',
                            style: TextStyles.blackNormalBold
                                .copyWith(fontSize: 14),
                          ),
                          const SizedBox(height: 12),

                          _buildTextField(
                            controller: _emailController,
                            label: 'Email',
                            icon: Icons.email_outlined,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Vui lòng nhập email';
                              }
                              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                                  .hasMatch(value.trim())) {
                                return 'Email không hợp lệ';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          _buildTextField(
                            controller: _passwordController,
                            label: 'Mật khẩu',
                            icon: Icons.lock_outline,
                            isPassword: true,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Vui lòng nhập mật khẩu';
                              }
                              if (value.trim().length < 6) {
                                return 'Mật khẩu phải có ít nhất 6 ký tự';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          _buildTextField(
                            controller: _confirmPasswordController,
                            label: 'Nhập lại mật khẩu',
                            icon: Icons.lock_outline,
                            isPassword: true,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Vui lòng nhập lại mật khẩu';
                              }
                              if (value.trim() !=
                                  _passwordController.text.trim()) {
                                return 'Mật khẩu không khớp';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Submit button
                    SizedBox(
                      height: 54,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submitForm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 2,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              )
                            : const Text(
                                'Đăng ký tài khoản',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword,
      cursorColor: AppColors.primary,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyles.blackNormalRegular.copyWith(
          color: AppColors.gray200,
          fontSize: 13,
        ),
        prefixIcon: Icon(icon, color: AppColors.slate400),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.gray200.withOpacity(0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.gray200.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.red),
        ),
      ),
      validator: validator,
    );
  }
}

class _RoleOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _RoleOption({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.blue : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? AppColors.blue
                : AppColors.gray200.withOpacity(0.3),
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : AppColors.gray200,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyles.blackNormalBold.copyWith(
                color: isSelected ? Colors.white : AppColors.gray200,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
