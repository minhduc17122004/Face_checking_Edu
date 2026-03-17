import 'package:flutter/material.dart';

class AccountPage extends StatelessWidget {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F8),
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
          bottom: BorderSide(color: Color(0xFFE2E8F0), width: 0.5),
        ),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Account Profile',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
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
        color: const Color(0xFF1e3b8a),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1e3b8a).withOpacity(0.35),
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
                const Text(
                  'Alex Johnson',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'alex.johnson@example.com',
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
                        color: const Color(0xFF4ADE80).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(
                          color: const Color(0xFF4ADE80).withOpacity(0.3),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.verified,
                              color: Color(0xFFBBF7D0), size: 16),
                          SizedBox(width: 6),
                          Text(
                            'Verified Student',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFBBF7D0),
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
          'Settings',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 14),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFE2E8F0).withOpacity(0.5)),
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
                title: 'Personal Information',
                iconBg: const Color(0xFFEFF6FF),
                iconColor: const Color(0xFF2563EB),
                onTap: () {},
              ),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              _SettingItem(
                icon: Icons.security,
                title: 'Security & Privacy',
                iconBg: const Color(0xFFF5F3FF),
                iconColor: const Color(0xFF9333EA),
                onTap: () {},
              ),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              _SettingItem(
                icon: Icons.notifications_outlined,
                title: 'Notifications',
                iconBg: const Color(0xFFFFF7ED),
                iconColor: const Color(0xFFEA580C),
                onTap: () {},
              ),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              _SettingItem(
                icon: Icons.help_outline,
                title: 'Help & Support',
                iconBg: const Color(0xFFF0FDFA),
                iconColor: const Color(0xFF0D9488),
                onTap: () {},
              ),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              _SettingItem(
                icon: Icons.logout,
                title: 'Log out',
                iconBg: const Color(0xFFFEE2E2),
                iconColor: const Color(0xFFDC2626),
                titleColor: const Color(0xFFDC2626),
                onTap: () {},
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
    this.titleColor = const Color(0xFF0F172A),
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
                color: Color(0xFF94A3B8),
              ),
          ],
        ),
      ),
    );
  }
}
