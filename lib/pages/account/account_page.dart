import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:face_time_keeping/common/resources/app_colors.dart';
import 'package:face_time_keeping/di/injection.dart';
import 'package:face_time_keeping/pages/account/account_cubit.dart';
import 'package:face_time_keeping/pages/account/account_state.dart';

import 'package:face_time_keeping/pages/widgets/app_dialog.dart';
import 'package:face_time_keeping/route/app_route.dart';
import 'package:face_time_keeping/route/navigator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  late final AccountCubit _accountCubit = getIt<AccountCubit>();

  @override
  void initState() {
    super.initState();
    _accountCubit.loadUserProfile();
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

    imageCache.clear();
    await _accountCubit.updateAvatar(picked.path);
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
            const Text(
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
                await _accountCubit.logout();
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
    _accountCubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AccountCubit, AccountState>(
      bloc: _accountCubit,
      listener: (context, state) {
        if (state.avatarUpdateStatus == AccountAvatarUpdateStatus.initial) {
          return;
        }

        if (state.avatarUpdateStatus == AccountAvatarUpdateStatus.failure) {
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
          _accountCubit.resetAvatarStatus();
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  state.backendSynced ? Icons.check_circle : Icons.cloud_off,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    state.backendSynced
                        ? 'Cập nhật ảnh đại diện thành công!'
                        : 'Đã lưu cục bộ, đồng bộ server sau.',
                  ),
                ),
              ],
            ),
            backgroundColor:
                state.backendSynced ? AppColors.green600 : AppColors.orange600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 2),
          ),
        );
        _accountCubit.resetAvatarStatus();
      },
      builder: (context, state) {
        return Scaffold(
          backgroundColor: AppColors.backgroundLight,
          body: SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async => _accountCubit.loadUserProfile(),
                    color: AppColors.primary,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),
                        _buildProfileCard(state),
                        const SizedBox(height: 24),
                        _buildSettings(),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
              ),
            ],
            ),
          ),
        );
      },
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
            'HỒ SƠ TÀI KHOẢN',
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

  Widget _buildAvatarWidget(AccountState state) {
    final isNetworkAvatar = state.avatarPath.startsWith('http://') ||
        state.avatarPath.startsWith('https://');
    final hasLocalAvatar = !isNetworkAvatar &&
        state.avatarPath.isNotEmpty &&
        File(state.avatarPath).existsSync();

    return GestureDetector(
      onTap: state.isUploadingAvatar ? null : _pickAndSaveAvatar,
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
              child: state.isUploadingAvatar
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
                          imageUrl:
                              '${state.avatarPath}?t=${DateTime.now().millisecondsSinceEpoch}',
                          fit: BoxFit.cover,
                          width: 88,
                          height: 88,
                          errorWidget: (context, url, error) =>
                              _buildDefaultAvatar(state.displayName),
                          placeholder: (context, url) => Container(
                            color: AppColors.slate200,
                            child: const Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        )
                      : hasLocalAvatar
                          ? Image.file(
                              File(state.avatarPath),
                              fit: BoxFit.cover,
                              width: 88,
                              height: 88,
                              errorBuilder: (_, __, ___) =>
                                  _buildDefaultAvatar(state.displayName),
                            )
                          : _buildDefaultAvatar(state.displayName),
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

  Widget _buildDefaultAvatar(String displayName) {
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
          displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U',
          style: const TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildProfileCard(AccountState state) {
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
                Center(child: _buildAvatarWidget(state)),
                const SizedBox(height: 16),
                Text(
                  state.displayName,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  state.displayEmail,
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
                onTap: () {
                  AppNavigator.pushNamed(RouterName.profile);
                },
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
