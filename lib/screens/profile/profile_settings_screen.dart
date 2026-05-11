// lib/screens/profile/profile_settings_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/user_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/profile/profile_photo_widget.dart';
import '../../widgets/profile/location_preference_widget.dart';
import '../../widgets/profile/verification_badge_widget.dart';
import 'verification_selfie_screen.dart';

class ProfileSettingsScreen extends StatelessWidget {
  const ProfileSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>().user;

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: AppColors.darkBg,
        title: const Text(
          'Profile Settings',
          style: TextStyle(color: AppColors.white, fontWeight: FontWeight.w700),
        ),
        iconTheme: const IconThemeData(color: AppColors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Profile photo
            const ProfilePhotoWidget(),
            const SizedBox(height: 12),

            // Display name
            if (user != null)
              Text(
                user.displayName.isNotEmpty ? user.displayName : user.email,
                style: const TextStyle(
                  color: AppColors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),

            const SizedBox(height: 8),

            // Verification badge
            if (user != null) ...[
              VerificationBadgeWidget(status: user.verificationStatus),
              const SizedBox(height: 8),
              if (!user.isVerified)
                OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const VerificationSelfieScreen(),
                    ),
                  ),
                  icon: const Icon(
                    Icons.camera_front,
                    size: 16,
                    color: AppColors.yellow,
                  ),
                  label: const Text(
                    'Get Verified',
                    style: TextStyle(color: AppColors.yellow, fontSize: 12),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.yellow),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
            ],

            Divider(height: 36, color: AppColors.border),

            // Location + food preferences
            const LocationPreferenceWidget(),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
