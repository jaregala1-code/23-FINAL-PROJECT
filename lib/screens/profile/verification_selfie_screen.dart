// lib/screens/profile/verification_selfie_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/app_user.dart';
import '../../providers/user_provider.dart';
import '../../services/verification_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/profile/verification_badge_widget.dart';

class VerificationSelfieScreen extends StatefulWidget {
  const VerificationSelfieScreen({super.key});

  @override
  State<VerificationSelfieScreen> createState() =>
      _VerificationSelfieScreenState();
}

class _VerificationSelfieScreenState extends State<VerificationSelfieScreen> {
  bool _submitting = false;

  Future<void> _submit() async {
    final userProvider = context.read<UserProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final uid = userProvider.user?.uid;
    if (uid == null) return;

    setState(() => _submitting = true);
    final ok = await VerificationService.instance.captureAndSubmit(uid);
    if (ok) await userProvider.loadUser(uid);
    if (!mounted) return;

    setState(() => _submitting = false);

    if (ok) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text("Selfie submitted! You'll be notified once verified."),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final status =
        context.watch<UserProvider>().user?.verificationStatus ??
        VerificationStatus.unverified;
    final isPendingOrVerified =
        status == VerificationStatus.pending ||
        status == VerificationStatus.verified;

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: AppColors.darkBg,
        title: const Text(
          'Identity Verification',
          style: TextStyle(color: AppColors.white, fontWeight: FontWeight.w700),
        ),
        iconTheme: const IconThemeData(color: AppColors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 16),
            VerificationBadgeWidget(status: status),
            const SizedBox(height: 32),

            // Instructions
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: const Column(
                children: [
                  Icon(Icons.info_outline, color: AppColors.yellow),
                  SizedBox(height: 8),
                  Text(
                    'Take a clear selfie using your front camera. '
                    'Make sure your face is fully visible and well-lit.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.mutedText, fontSize: 13),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            if (_submitting)
              const CircularProgressIndicator(color: AppColors.yellow)
            else if (isPendingOrVerified)
              Column(
                children: [
                  Icon(
                    status == VerificationStatus.verified
                        ? Icons.verified
                        : Icons.check_circle_outline,
                    color: status == VerificationStatus.verified
                        ? AppColors.green
                        : AppColors.orange,
                    size: 56,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    status == VerificationStatus.verified
                        ? 'You are verified!'
                        : 'Selfie submitted — under review.',
                    style: const TextStyle(
                      color: AppColors.white,
                      fontSize: 15,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              )
            else
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _submit,
                  icon: const Icon(Icons.camera_front),
                  label: const Text('Take Verification Selfie'),
                ),
              ),

            const SizedBox(height: 20),
            const Text(
              'Your photo is used only for identity verification\n'
              'and is never visible to other users.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.mutedText, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
