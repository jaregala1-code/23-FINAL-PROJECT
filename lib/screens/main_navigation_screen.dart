import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_theme.dart';
import 'dummy_home_screen.dart';
import 'create_post_screen.dart';
import 'messages_screen.dart';
import 'profile_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  final User firebaseUser;

  const MainNavigationScreen({super.key, required this.firebaseUser});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      const DummyHomeScreen(),
      const CreatePostScreen(),
      MessagesScreen(firebaseUser: widget.firebaseUser),
      ProfileScreen(firebaseUser: widget.firebaseUser),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: _ElBitesNavBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
      ),
    );
  }
}

class _ElBitesNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _ElBitesNavBar({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        border: const Border(
          top: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              _NavItem(
                icon: Icons.home_outlined,
                activeIcon: Icons.home_rounded,
                label: 'Home',
                isActive: currentIndex == 0,
                onTap: () => onTap(0),
              ),
              _NavItem(
                icon: Icons.add_circle_outline_rounded,
                activeIcon: Icons.add_circle_rounded,
                label: 'Post',
                isActive: currentIndex == 1,
                onTap: () => onTap(1),
                isAccent: true,
              ),
              _NavItem(
                icon: Icons.inbox_outlined,
                activeIcon: Icons.inbox_rounded,
                label: 'Messages',
                isActive: currentIndex == 2,
                onTap: () => onTap(2),
              ),
              _NavItem(
                icon: Icons.person_outline_rounded,
                activeIcon: Icons.person_rounded,
                label: 'Profile',
                isActive: currentIndex == 3,
                onTap: () => onTap(3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final bool isAccent;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    required this.onTap,
    this.isAccent = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color activeColor = isAccent ? AppColors.yellow : AppColors.green;
    final Color inactiveColor = AppColors.mutedText;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isActive ? activeIcon : icon,
              color: isActive ? activeColor : inactiveColor,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isActive ? activeColor : inactiveColor,
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
