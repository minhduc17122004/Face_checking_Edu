import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:face_time_keeping/common/resources/index.dart';
import 'package:face_time_keeping/common/utils/alerts.dart';
import 'package:face_time_keeping/di/injection.dart';
import 'package:face_time_keeping/entities/room.dart';
import 'package:face_time_keeping/pages/room/bloc/room_bloc.dart';
import 'package:face_time_keeping/route/navigator.dart';
import 'package:face_time_keeping/common/enums/request_status.dart';

class RoomFormPage extends StatefulWidget {
  final Room? room;

  const RoomFormPage({super.key, this.room});

  @override
  State<RoomFormPage> createState() => _RoomFormPageState();
}

class _RoomFormPageState extends State<RoomFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _capacityController;
  bool _isLoading = false;

  bool get _isEditing => widget.room != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.room?.name);
    _capacityController = TextEditingController(
      text: widget.room?.capacity?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _capacityController.dispose();
    super.dispose();
  }

  Future<void> _submit(BuildContext context) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final bloc = getIt<RoomBloc>();
    final capacity = _capacityController.text.trim().isEmpty
        ? null
        : int.tryParse(_capacityController.text.trim());

    if (_isEditing) {
      await bloc.updateRoom(
        id: widget.room!.id,
        name: _nameController.text.trim(),
        capacity: capacity,
      );
    } else {
      await bloc.createRoom(
        name: _nameController.text.trim(),
        capacity: capacity,
      );
    }

    if (mounted) {
      if (bloc.state.requestStatus == RequestStatus.success) {
        showTopAlert(
          context,
          title: _isEditing ? 'Cập nhật phòng học thành công!' : 'Tạo phòng học thành công!',
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
          _isEditing ? 'SỬA PHÒNG HỌC' : 'THÊM PHÒNG HỌC',
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
                  const Text(
                    'Thông tin phòng học',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _nameController,
                    label: 'Tên phòng',
                    hint: 'A101',
                    inputFormatters: [LengthLimitingTextInputFormatter(4)],
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Vui lòng nhập tên phòng';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _capacityController,
                    label: 'Sức chứa (tùy chọn)',
                    hint: '40',
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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
                  elevation: 0,
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
                        _isEditing ? 'Lưu thay đổi' : 'Tạo phòng học',
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
}
