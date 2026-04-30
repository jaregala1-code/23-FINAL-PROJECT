import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import 'splash_screen.dart';
import 'profile_screen.dart';

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
          return const SplashScreen();
        }

        final user = snapshot.data!;

        // Load app user data if not loaded
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final provider = context.read<UserAuthProvider>();
          if (provider.appUser == null) {
            provider.loadAppUser(user.uid);
          }
        });

        return ProfileScreen(firebaseUser: user);
      },
    );
  }
}
