import 'package:face_time_keeping/common/api_client/data_state.dart';
import 'package:face_time_keeping/common/resources/app_colors.dart';
import 'package:face_time_keeping/data/remote/authentication/login_response.dart';
import 'package:face_time_keeping/data/remote/authentication_service.dart';
import 'package:face_time_keeping/di/injection.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late Future<DataState<UserInfo>> _profileFuture;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  void _fetchProfile() {
    _profileFuture = getIt<AuthenticationService>().getMe();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text(
          'Thông tin cá nhân',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppColors.primary,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: FutureBuilder<DataState<UserInfo>>(
        future: _profileFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            );
          }

          if (snapshot.hasError) {
            return _buildErrorState('Lỗi kết nối: ${snapshot.error}');
          }

          final dataState = snapshot.data;
          if (dataState == null ||
              !dataState.isSuccess ||
              dataState.data == null) {
            return _buildErrorState(
                dataState?.error ?? 'Không thể tải thông tin cá nhân');
          }

          final profile = dataState.data!;
          return _buildProfileContent(profile);
        },
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 60, color: AppColors.red600),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                color: AppColors.slate900,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _fetchProfile();
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child:
                  const Text('Thử lại', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileContent(UserInfo profile) {
    String roleDisplay = 'Học sinh';
    if (profile.role?.toLowerCase() == 'teacher') roleDisplay = 'Giáo viên';
    if (profile.role?.toLowerCase() == 'admin') roleDisplay = 'Quản trị viên';

    return RefreshIndicator(
      onRefresh: () async {
        setState(() {
          _fetchProfile();
        });
        await _profileFuture;
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          children: [
            _buildAvatarWidget(profile),
            const SizedBox(height: 16),
            Text(
              profile.fullName ?? 'Chưa cập nhật tên',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.slate900,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.blue50,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                roleDisplay,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.blue600,
                ),
              ),
            ),
            const SizedBox(height: 32),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.slate200.withOpacity(0.5)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _InfoItem(
                    icon: Icons.email_outlined,
                    label: 'Email',
                    value: profile.email ?? 'Không có email',
                  ),
                  if (profile.studentCode != null &&
                      profile.studentCode!.isNotEmpty) ...[
                    const Divider(height: 1, color: AppColors.slate200),
                    _InfoItem(
                      icon: Icons.badge_outlined,
                      label: profile.role?.toLowerCase() == 'teacher'
                          ? 'Mã cán bộ'
                          : 'Mã sinh viên',
                      value: profile.studentCode!,
                    ),
                  ],
                  if (profile.className != null &&
                      profile.className!.isNotEmpty) ...[
                    const Divider(height: 1, color: AppColors.slate200),
                    _InfoItem(
                      icon: Icons.class_outlined,
                      label: profile.role?.toLowerCase() == 'teacher'
                          ? 'Phòng ban'
                          : 'Lớp',
                      value: profile.className!,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarWidget(UserInfo profile) {
    final avatarUrl = profile.avatarUrl;
    final isNetwork = avatarUrl != null &&
        (avatarUrl.startsWith('http://') || avatarUrl.startsWith('https://'));

    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: AppColors.primary,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipOval(
        child: isNetwork
            ? CachedNetworkImage(
                imageUrl: avatarUrl,
                fit: BoxFit.cover,
                errorWidget: (context, url, error) =>
                    _buildDefaultAvatar(profile.fullName),
                placeholder: (context, url) =>
                    const CircularProgressIndicator(),
              )
            : _buildDefaultAvatar(profile.fullName),
      ),
    );
  }

  Widget _buildDefaultAvatar(String? name) {
    final displayChar =
        (name != null && name.isNotEmpty) ? name[0].toUpperCase() : 'U';
    return Container(
      color: AppColors.primary,
      child: Center(
        child: Text(
          displayChar,
          style: const TextStyle(
            fontSize: 40,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _InfoItem extends StatelessWidget {
  const _InfoItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.slate200.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.slate500, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.slate500,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    color: AppColors.slate900,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
