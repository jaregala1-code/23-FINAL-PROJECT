import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import 'splash_screen.dart';
import 'main_navigation_screen.dart';
import '../providers/notification_provider.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userStream = context.watch<UserAuthProvider>().userStream;

    return StreamBuilder<User?>(
      stream: userStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: AppColors.darkBg,
            body: Center(
              child: CircularProgressIndicator(
                color: AppColors.yellow,
                strokeWidth: 2.5,
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return const Scaffold(
            backgroundColor: AppColors.darkBg,
            body: Center(
              child: Text(
                'Something went wrong.',
                style: TextStyle(color: AppColors.mutedText),
              ),
            ),
          );
        }

        if (!snapshot.hasData) {
          // Tear down the per-user notification stream when the user signs
          // out, so the listener doesn't error after auth is cleared.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!context.mounted) return;
            context.read<NotificationProvider>().bindUser(null);
          });
          return const SplashScreen();
        }

        final user = snapshot.data!;

        // Load app user data if not already loaded.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final provider = context.read<UserAuthProvider>();
          final current = FirebaseAuth.instance.currentUser;
          if (provider.appUser == null &&
              current != null &&
              current.uid == user.uid) {
            provider.loadAppUser(user.uid);
          }
        });

        // Authenticated; show main navigation with bottom nav bar
        return MainNavigationScreen(firebaseUser: user);
      },
    );
  }
}
