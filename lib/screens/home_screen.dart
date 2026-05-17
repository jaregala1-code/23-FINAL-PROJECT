import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import 'splash_screen.dart';
import 'main_navigation_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _loadedUid;

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

        final user = snapshot.data;
        if (user == null) {
          _loadedUid = null;
          return const SplashScreen();
        }

        if (_loadedUid != user.uid) {
          _loadedUid = user.uid;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final provider = context.read<UserAuthProvider>();
            if (provider.appUser == null) provider.loadAppUser(user.uid);
          });
        }

        return MainNavigationScreen(firebaseUser: user);
      },
    );
  }
}
