import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:face_time_keeping/common/api_client/api_client.dart';
import 'package:face_time_keeping/common/resources/app_colors.dart';
import 'package:face_time_keeping/data/local/local_service.dart';
import 'package:face_time_keeping/data/remote/api_endpoint.dart';
import 'package:face_time_keeping/di/injection.dart';
import 'package:face_time_keeping/pages/setting/cubit/setting/setting_cubit.dart';
import 'package:face_time_keeping/pages/widgets/app_dialog.dart';
import 'package:face_time_keeping/route/app_route.dart';
import 'package:face_time_keeping/route/navigator.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  late final SettingCubit _settingCubit = getIt();
  late final LocalService _localService = getIt<LocalService>();
  String _displayName = 'Người dùng';
  String _displayEmail = 'user@example.com';
  String _avatarPath = '';
  bool _isUploadingAvatar = false;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  void _loadUserProfile() {
    final fullName = _localService.getUserFullName().trim();
    final email = _localService.getUserEmail().trim();
    final avatarPath = _localService.getAvatarPath();

    final fallbackName =
        email.isNotEmpty ? email.split('@').first : 'Người dùng';
    setState(() {
      _displayName = fullName.isNotEmpty ? fullName : fallbackName;
      _displayEmail = email.isNotEmpty ? email : 'user@example.com';
      _avatarPath = avatarPath;
    });
  }

  Future<void> _pickAndSaveAvatar() async {
    final source = await _showAvatarSourcePicker();
    if (source == null) return;

    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 512,
      maxHeight: 512,
    );
    if (picked == null) return;

    setState(() => _isUploadingAvatar = true);

    try {
      // 1. Save locally for offline access
      final appDir = await getApplicationDocumentsDirectory();
      final avatarDir = Directory(p.join(appDir.path, 'avatars'));
      if (!avatarDir.existsSync()) {
        avatarDir.createSync(recursive: true);
      }

      final ext = p.extension(picked.path).isNotEmpty
          ? p.extension(picked.path)
          : '.jpg';

      // Xoá file ảnh của avatar rác từ phiên làm việc trước của CHÍNH user này
      if (_avatarPath.isNotEmpty) {
        final oldFile = File(_avatarPath);
        if (oldFile.existsSync()) {
          try {
            oldFile.deleteSync();
          } catch (_) {}
        }
      }

      // Đặt tên file chứa timestamp + email để phân biệt rõ ràng
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final safeEmail = _displayEmail.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
      final savedFile = File(p.join(avatarDir.path, 'avatar_${safeEmail}_$timestamp$ext'));

      await File(picked.path).copy(savedFile.path);
      
      // Xoá Image cache cũ của Flutter (chắc chắn 100% UI sẽ update)
      imageCache.clear();
      // Không lưu cứng local ngay từ đầu nữa, hãy đợi xem Backend trả về gì
      String newAvatarPath = savedFile.path;

      // 2. Upload to backend
      bool backendSuccess = false;
      try {
        final apiClient = getIt<ApiClient>();
        final formData = FormData.fromMap({
          'file': await MultipartFile.fromFile(
            savedFile.path,
            filename: 'avatar$ext',
          ),
        });
        
        final response = await apiClient.dio.post(
          ApiEndpoint.uploadUserAvatar,
          data: formData,
          options: Options(
            contentType: 'multipart/form-data',
            sendTimeout: 120000, // 120s for Dio v4
            receiveTimeout: 120000, 
          ),
          onSendProgress: (int sent, int total) {
            debugPrint("Upload Avatar: ${(sent / total * 100).toStringAsFixed(0)}%");
          },
        );
        backendSuccess = (response.statusCode != null && response.statusCode! >= 200 && response.statusCode! < 300);
        
        // Trích xuất URL Network từ Backend
        if (backendSuccess && response.data != null && response.data['avatar_url'] != null) {
          final baseUrl = apiClient.dio.options.baseUrl;
          var urlSuffix = response.data['avatar_url'] as String;
          if (baseUrl.endsWith('/') && urlSuffix.startsWith('/')) {
             urlSuffix = urlSuffix.substring(1);
          }
          newAvatarPath = (baseUrl.endsWith('/') ? baseUrl : '$baseUrl/') + (urlSuffix.startsWith('/') ? urlSuffix.substring(1) : urlSuffix);
        }
      } catch (e) {
        debugPrint("Lỗi upload avatar: $e");
        // Backend upload failed silently — local copy is still saved fallback
      }

      _localService.saveAvatarPath(newAvatarPath);

      if (!mounted) return;
      setState(() {
        _avatarPath = newAvatarPath;
        _isUploadingAvatar = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                backendSuccess ? Icons.check_circle : Icons.cloud_off,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  backendSuccess
                      ? 'Cập nhật ảnh đại diện thành công!'
                      : 'Đã lưu cục bộ, đồng bộ server sau.',
                ),
              ),
            ],
          ),
          backgroundColor:
              backendSuccess ? AppColors.green600 : AppColors.orange600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploadingAvatar = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Text('Không thể cập nhật ảnh đại diện.'),
            ],
          ),
          backgroundColor: AppColors.red600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  Future<ImageSource?> _showAvatarSourcePicker() {
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.slate400.withOpacity(0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Chọn ảnh đại diện',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.slate900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Chọn nguồn ảnh để cập nhật avatar',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.slate500,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _AvatarSourceOption(
                    icon: Icons.camera_alt_rounded,
                    label: 'Chụp ảnh',
                    color: AppColors.blue600,
                    bgColor: AppColors.blue50,
                    onTap: () => Navigator.pop(ctx, ImageSource.camera),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _AvatarSourceOption(
                    icon: Icons.photo_library_rounded,
                    label: 'Thư viện',
                    color: AppColors.purple600,
                    bgColor: AppColors.purple50,
                    onTap: () => Navigator.pop(ctx, ImageSource.gallery),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AppDialog(
          title: 'Đăng xuất',
          icon: Icons.logout,
          accentColor: AppColors.red600,
          content: const Text('Bạn có chắc chắn muốn đăng xuất?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.gray200,
              ),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () async {
                await _settingCubit.logout();
                if (!mounted) return;
                Navigator.of(dialogContext).pop();
                AppNavigator.pushNamedAndRemoveUntil(
                  RouterName.login,
                  (_) => false,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.red600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Đăng xuất'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _settingCubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    _buildProfileCard(),
                    const SizedBox(height: 24),
                    _buildSettings(),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: AppColors.slate200, width: 0.5),
        ),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Hồ sơ tài khoản',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.slate900,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarWidget() {
    final bool isNetworkAvatar = _avatarPath.startsWith('http') || _avatarPath.startsWith('https');
    final bool hasLocalAvatar =
        !isNetworkAvatar && _avatarPath.isNotEmpty && File(_avatarPath).existsSync();

    return GestureDetector(
      onTap: _isUploadingAvatar ? null : _pickAndSaveAvatar,
      child: Stack(
        children: [
          // Avatar circle
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withOpacity(0.6),
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipOval(
              child: _isUploadingAvatar
                  ? Container(
                      color: Colors.black26,
                      child: const Center(
                        child: SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                      ),
                    )
                  : isNetworkAvatar
                      ? CachedNetworkImage(
                          imageUrl: '$_avatarPath?t=${DateTime.now().millisecondsSinceEpoch}', // bypass Network Cache
                          fit: BoxFit.cover,
                          width: 88,
                          height: 88,
                          errorWidget: (context, url, error) => _buildDefaultAvatar(),
                          placeholder: (context, url) => Container(
                             color: AppColors.slate200,
                             child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                          ),
                        )
                      : hasLocalAvatar
                          ? Image.file(
                              File(_avatarPath),
                              fit: BoxFit.cover,
                              width: 88,
                              height: 88,
                              errorBuilder: (_, __, ___) => _buildDefaultAvatar(),
                            )
                          : _buildDefaultAvatar(),
            ),
          ),
          // Camera badge
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: const BoxDecoration(
                    color: AppColors.blue600,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.camera_alt_rounded,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultAvatar() {
    return Container(
      width: 88,
      height: 88,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.blue[300]!,
            Colors.blue[600]!,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          _displayName.isNotEmpty ? _displayName[0].toUpperCase() : 'U',
          style: const TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildProfileCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // decorative circles
          Positioned(
            right: -30,
            top: -30,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            left: -30,
            bottom: -10,
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                color: Colors.blue[300]!.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 10),
                Center(child: _buildAvatarWidget()),
                const SizedBox(height: 16),
                Text(
                  _displayName,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _displayEmail,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.blue[100],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.green300.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(
                          color: AppColors.green300.withOpacity(0.3),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.verified,
                              color: AppColors.green200, size: 16),
                          SizedBox(width: 6),
                          Text(
                            'Đã xác minh',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.green200,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Cài đặt',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: AppColors.slate900,
          ),
        ),
        const SizedBox(height: 14),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.slate200.withOpacity(0.5)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              _SettingItem(
                icon: Icons.person_outline,
                title: 'Thông tin cá nhân',
                iconBg: AppColors.blue50,
                iconColor: AppColors.blue600,
                onTap: () {},
              ),
              const Divider(height: 1, color: AppColors.slate200),
              _SettingItem(
                icon: Icons.security,
                title: 'Bảo mật và riêng tư',
                iconBg: AppColors.purple50,
                iconColor: AppColors.purple600,
                onTap: () {},
              ),
              const Divider(height: 1, color: AppColors.slate200),
              _SettingItem(
                icon: Icons.notifications_outlined,
                title: 'Thông báo',
                iconBg: AppColors.orange50,
                iconColor: AppColors.orange600,
                onTap: () {},
              ),
              const Divider(height: 1, color: AppColors.slate200),
              _SettingItem(
                icon: Icons.help_outline,
                title: 'Trợ giúp và hỗ trợ',
                iconBg: AppColors.teal50,
                iconColor: AppColors.teal600,
                onTap: () {},
              ),
              const Divider(height: 1, color: AppColors.slate200),
              _SettingItem(
                icon: Icons.logout,
                title: 'Đăng xuất',
                iconBg: AppColors.red100,
                iconColor: AppColors.red600,
                titleColor: AppColors.red600,
                onTap: _showLogoutDialog,
                showArrow: false,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AvatarSourceOption extends StatelessWidget {
  const _AvatarSourceOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.bgColor,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color bgColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 26),
              ),
              const SizedBox(height: 10),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingItem extends StatelessWidget {
  const _SettingItem({
    required this.icon,
    required this.title,
    required this.iconBg,
    required this.iconColor,
    required this.onTap,
    this.titleColor = AppColors.slate900,
    this.showArrow = true,
  });

  final IconData icon;
  final String title;
  final Color iconBg;
  final Color iconColor;
  final Color titleColor;
  final VoidCallback onTap;
  final bool showArrow;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconBg,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: titleColor,
                ),
              ),
            ),
            if (showArrow)
              const Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: AppColors.slate400,
              ),
          ],
        ),
      ),
    );
  }
}
