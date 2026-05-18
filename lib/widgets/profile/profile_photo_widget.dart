// lib/widgets/profile/profile_photo_widget.dart

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../providers/user_provider.dart';
import '../../services/image_service.dart';
import '../../theme/app_theme.dart';
import '../pantry/base64_image.dart';

class ProfilePhotoWidget extends StatefulWidget {
  const ProfilePhotoWidget({super.key});

  @override
  State<ProfilePhotoWidget> createState() => _ProfilePhotoWidgetState();
}

class _ProfilePhotoWidgetState extends State<ProfilePhotoWidget> {
  bool _uploading = false;

  Future<void> _upload(ImageSource source) async {
    setState(() => _uploading = true);
    final userProvider = context.read<UserProvider>();
    final base64 = await ImageService.instance.pickAndEncode(
      source: source,
      quality: 80,
      maxWidth: 800,
    );
    if (base64 != null) {
      await userProvider.updateUser({
        'profileImageBase64': base64,
        'profileImageUpdatedAt': DateTime.now().toIso8601String(),
      });
    }
    if (!mounted) return;
    setState(() => _uploading = false);
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>().user;
    final hasPhoto = user?.profileImageBase64 != null;

    return Column(
      children: [
        CircleAvatar(
          radius: 52,
          backgroundColor: AppColors.cardBg2,
          child: _uploading
              ? const CircularProgressIndicator(color: AppColors.yellow)
              : hasPhoto
              ? ClipOval(
                  child: Base64Image(
                    base64: user!.profileImageBase64!,
                    width: 104,
                    height: 104,
                  ),
                )
              : const Icon(Icons.person, size: 52, color: AppColors.mutedText),
        ),
        const SizedBox(height: 12),
        if (!_uploading)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _UploadButton(
                icon: Icons.camera_alt_outlined,
                label: 'Camera',
                onTap: () => _upload(ImageSource.camera),
              ),
              const SizedBox(width: 12),
              _UploadButton(
                icon: Icons.photo_library_outlined,
                label: 'Gallery',
                onTap: () => _upload(ImageSource.gallery),
              ),
            ],
          ),
      ],
    );
  }
}

class _UploadButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _UploadButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: onTap,
    icon: Icon(icon, size: 16, color: AppColors.yellow),
    label: Text(
      label,
      style: const TextStyle(fontSize: 12, color: AppColors.yellow),
    ),
    style: OutlinedButton.styleFrom(
      side: const BorderSide(color: AppColors.yellow),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    ),
  );
}
