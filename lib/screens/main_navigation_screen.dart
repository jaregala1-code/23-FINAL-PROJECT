// lib/screens/main_navigation_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

import '../providers/pantry_provider.dart';
import '../theme/app_theme.dart';
import 'pantry/pantry_screen.dart';
import 'pantry/tray_screen.dart';
import 'pantry/add_item_screen.dart';
import 'chat/chat_list_screen.dart';
import 'profile_screen.dart';
import 'notifications_screen.dart';

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
      const PantryScreen(),
      const TrayScreen(),
      const AddItemScreen(),
      ChatListScreen(firebaseUser: widget.firebaseUser),
      ProfileScreen(firebaseUser: widget.firebaseUser),
    ];

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<PantryProvider>().startListening();
    });
  }

  @override
  void dispose() {
    // PantryProvider auto-cancels in its own dispose;
    super.dispose();
  }

  void _openNotifications() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const NotificationsScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: AppColors.darkBg,
        automaticallyImplyLeading: false,
        title: RichText(
          text: const TextSpan(
            children: [
              TextSpan(
                text: 'EL',
                style: TextStyle(
                  color: AppColors.green,
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                  fontFamily: 'Sora',
                ),
              ),
              TextSpan(
                text: 'Bites',
                style: TextStyle(
                  color: AppColors.white,
                  fontWeight: FontWeight.w300,
                  fontSize: 20,
                  fontFamily: 'Sora',
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Notifications',
            icon: const Icon(
              Icons.notifications_outlined,
              color: AppColors.white,
            ),
            onPressed: _openNotifications,
          ),
        ],
      ),
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: _ElBitesNavBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
      ),
    );
  }
}

// ── Bottom nav bar ────────────────────────────────────────────────────────────

class _ElBitesNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  const _ElBitesNavBar({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.cardBg,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              _NavItem(
                icon: Icons.storefront_outlined,
                activeIcon: Icons.storefront_rounded,
                label: 'Pantry',
                isActive: currentIndex == 0,
                onTap: () => onTap(0),
              ),
              _NavItem(
                icon: Icons.shopping_basket_outlined,
                activeIcon: Icons.shopping_basket_rounded,
                label: 'Tray',
                isActive: currentIndex == 1,
                onTap: () => onTap(1),
              ),
              _NavItem(
                icon: Icons.add_circle_outline_rounded,
                activeIcon: Icons.add_circle_rounded,
                label: 'Post',
                isActive: currentIndex == 2,
                onTap: () => onTap(2),
                isAccent: true,
              ),
              _NavItem(
                icon: Icons.chat_bubble_outline_rounded,
                activeIcon: Icons.chat_bubble_rounded,
                label: 'Messages',
                isActive: currentIndex == 3,
                onTap: () => onTap(3),
              ),
              _NavItem(
                icon: Icons.person_outline_rounded,
                activeIcon: Icons.person_rounded,
                label: 'Profile',
                isActive: currentIndex == 4,
                onTap: () => onTap(4),
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
              color: isActive ? activeColor : AppColors.mutedText,
              size: 22,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: isActive ? activeColor : AppColors.mutedText,
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                fontFamily: 'Sora',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
