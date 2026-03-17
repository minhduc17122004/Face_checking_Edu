import 'package:flutter/material.dart';
import 'package:face_time_keeping/pages/home/home_page.dart';
import 'package:face_time_keeping/pages/account/account_page.dart';

class TabPage extends StatefulWidget {
  const TabPage({super.key});

  @override
  State<TabPage> createState() => _TabPageState();
}

class _TabPageState extends State<TabPage> {
  int _selectedNavIndex = 0;

  final List<Widget> _pages = [
    const HomePage(),
    const Center(child: Text("Classes")),
    const Center(child: Text("Messages")),
    const AccountPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedNavIndex,
        children: _pages,
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    const items = [
      {'icon': Icons.home, 'label': 'Home'},
      {'icon': Icons.school, 'label': 'Classes'},
      {'icon': Icons.chat_bubble_outline, 'label': 'Messages'},
      {'icon': Icons.person_outline, 'label': 'Account'},
    ];

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0), width: 0.5)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(items.length, (i) {
          final selected = _selectedNavIndex == i;
          return GestureDetector(
            onTap: () => setState(() => _selectedNavIndex = i),
            behavior: HitTestBehavior.opaque,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xFF1e3b8a).withOpacity(0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Icon(
                    items[i]['icon'] as IconData,
                    size: 22,
                    color: selected
                        ? const Color(0xFF1e3b8a)
                        : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  items[i]['label'] as String,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: selected
                        ? const Color(0xFF1e3b8a)
                        : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}
