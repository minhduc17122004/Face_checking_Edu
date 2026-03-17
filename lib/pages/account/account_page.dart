import 'package:flutter/material.dart';
import 'package:face_time_keeping/common/resources/app_colors.dart';
import 'package:face_time_keeping/data/local/local_service.dart';
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

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  void _loadUserProfile() {
    final fullName = _localService.getUserFullName().trim();
    final email = _localService.getUserEmail().trim();

    final fallbackName =
        email.isNotEmpty ? email.split('@').first : 'Người dùng';
    setState(() {
      _displayName = fullName.isNotEmpty ? fullName : fallbackName;
      _displayEmail = email.isNotEmpty ? email : 'user@example.com';
    });
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
                Center(
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: Colors.white.withOpacity(0.5), width: 3),
                      image: const DecorationImage(
                        image: NetworkImage(
                          'https://lh3.googleusercontent.com/aida-public/AB6AXuAszK3UNeXtqQiZl5vOJHSZhDDMAIKzpe68uWFgCfUjFAMWVE1RtPluFqogf7QdjbE9GYE6PEeZqNyCdj0o0dxVvgybdkcJ78_hWEJrY6-M4U42Kgale564zHQht0a8R6cijdY4zjkZqZE6s-RZhLGLtsZE1BPWSVsdL8JJEf_Ud6iKEZwtRx3c0xjgYOOCFzV_aKzHX_DUnfzgLXt3ADjV54nNUiyQ2MMBojOGW31hAIQdBJ8thx1pDJVMMW6B5K4F5KqOkk0e--A',
                        ),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
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
