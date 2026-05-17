// lib/screens/profile_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../providers/auth_provider.dart';
import '../providers/user_provider.dart';
import '../theme/app_theme.dart';
import '../models/app_user.dart';
import '../widgets/dietary_tag_chip.dart';
import '../widgets/pantry/base64_image.dart';
import 'profile/profile_settings_screen.dart';
import '../providers/pantry_provider.dart';

class ProfileScreen extends StatelessWidget {
  final User firebaseUser;
  const ProfileScreen({super.key, required this.firebaseUser});

  @override
  Widget build(BuildContext context) {
    final appUser =
        context.watch<UserProvider>().user ??
        context.watch<UserAuthProvider>().appUser;

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: CustomScrollView(
        slivers: [
          // ── Sliver App Bar ──────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 230,
            pinned: true,
            backgroundColor: AppColors.darkBg,
            actions: [
              IconButton(
                icon: const Icon(
                  Icons.settings_outlined,
                  color: AppColors.white,
                  size: 20,
                ),
                tooltip: 'Settings',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ProfileSettingsScreen(),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.logout_rounded,
                  color: AppColors.mutedText,
                  size: 20,
                ),
                tooltip: 'Sign out',
                onPressed: () async {
                  // Stop the pantry stream FIRST so it doesn't fire
                  // PERMISSION_DENIED errors against the new no-auth state.
                  context.read<PantryProvider>().stopListening();
                  context.read<UserProvider>().clear();
                  await context.read<UserAuthProvider>().signOut();
                },
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF1a2e14), AppColors.darkBg],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 24,
                    left: 24,
                    right: 24,
                    child: Row(
                      children: [
                        // Avatar — base64 or initial
                        _Avatar(appUser: appUser, firebaseUser: firebaseUser),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                appUser?.displayName.isNotEmpty == true
                                    ? appUser!.displayName
                                    : (firebaseUser.displayName ??
                                          'Community Member'),
                                style: const TextStyle(
                                  color: AppColors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              _VerificationBadge(user: appUser),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Body ────────────────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Info card
                _SectionCard(
                  child: Column(
                    children: [
                      _InfoRow(
                        icon: Icons.person_outline_rounded,
                        label: 'Full Name',
                        value:
                            appUser != null &&
                                (appUser.firstName.isNotEmpty ||
                                    appUser.lastName.isNotEmpty)
                            ? '${appUser.firstName} ${appUser.lastName}'.trim()
                            : (firebaseUser.displayName ?? '—'),
                      ),
                      const _Divider(),
                      _InfoRow(
                        icon: Icons.mail_outline_rounded,
                        label: 'Email',
                        value: appUser?.email ?? firebaseUser.email ?? '—',
                      ),
                      const _Divider(),
                      _InfoRow(
                        icon: Icons.alternate_email_rounded,
                        label: 'Username',
                        value: appUser?.displayName.isNotEmpty == true
                            ? appUser!.displayName
                            : '—',
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Food tags
                Row(
                  children: [
                    const Text(
                      'My Food Interests',
                      style: TextStyle(
                        color: AppColors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                      ),
                    ),
                    const Spacer(),
                    if (appUser != null && appUser.foodTagIds.isNotEmpty)
                      Text(
                        '${appUser.foodTagIds.length} selected',
                        style: const TextStyle(
                          color: AppColors.mutedText,
                          fontSize: 13,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                if (appUser == null || appUser.foodTagIds.isEmpty)
                  _EmptyTagsCard()
                else
                  _SectionCard(
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: kFoodTags
                            .where((t) => appUser.foodTagIds.contains(t.id))
                            .map(
                              (tag) => DietaryTagChip(
                                tag: DietaryTagCompat(
                                  id: tag.id,
                                  label: tag.label,
                                  emoji: tag.emoji,
                                ),
                                isSelected: true,
                                onTap: () {},
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ),

                const SizedBox(height: 20),

                // Stats
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        emoji: '🥡',
                        value: '0',
                        label: 'Shared',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        emoji: '🤝',
                        value: '0',
                        label: 'Claims',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(emoji: '⭐', value: '—', label: 'Rating'),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Verification CTA if not verified
                if (appUser?.isVerified != true)
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ProfileSettingsScreen(),
                      ),
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.orange.withValues(alpha: 0.12),
                            AppColors.yellow.withValues(alpha: 0.08),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: AppColors.orange.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: const [
                          Text('📸', style: TextStyle(fontSize: 28)),
                          SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Get Verified',
                                  style: TextStyle(
                                    color: AppColors.yellow,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                  ),
                                ),
                                SizedBox(height: 3),
                                Text(
                                  'Upload a selfie to build trust with your community.',
                                  style: TextStyle(
                                    color: AppColors.mutedText,
                                    fontSize: 13,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 14,
                            color: AppColors.orange,
                          ),
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: 40),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  final AppUser? appUser;
  final User firebaseUser;
  const _Avatar({required this.appUser, required this.firebaseUser});

  @override
  Widget build(BuildContext context) {
    final hasPhoto = appUser?.profileImageBase64 != null;
    return CircleAvatar(
      radius: 36,
      backgroundColor: AppColors.green,
      child: hasPhoto
          ? ClipOval(
              child: Base64Image(
                base64: appUser!.profileImageBase64!,
                width: 72,
                height: 72,
              ),
            )
          : Text(
              (appUser?.firstName.isNotEmpty == true
                      ? appUser!.firstName[0]
                      : (firebaseUser.displayName?[0] ?? 'U'))
                  .toUpperCase(),
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: AppColors.white,
              ),
            ),
    );
  }
}

class _VerificationBadge extends StatelessWidget {
  final AppUser? user;
  const _VerificationBadge({required this.user});

  @override
  Widget build(BuildContext context) {
    final status = user?.verificationStatus ?? VerificationStatus.unverified;
    Color color;
    IconData icon;
    String label;
    switch (status) {
      case VerificationStatus.verified:
        color = AppColors.green;
        icon = Icons.verified_rounded;
        label = 'Verified';
        break;
      case VerificationStatus.pending:
        color = AppColors.orange;
        icon = Icons.hourglass_top_rounded;
        label = 'Pending Review';
        break;
      case VerificationStatus.rejected:
        color = const Color(0xFFcf6679);
        icon = Icons.cancel_outlined;
        label = 'Rejected';
        break;
      default:
        color = AppColors.mutedText;
        icon = Icons.shield_outlined;
        label = 'Unverified';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final Widget child;
  const _SectionCard({required this.child});
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.cardBg,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppColors.border),
    ),
    child: child,
  );
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      children: [
        Icon(icon, size: 18, color: AppColors.mutedText),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(color: AppColors.mutedText, fontSize: 11),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(
                color: AppColors.white,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) =>
      const Divider(height: 1, color: AppColors.border);
}

class _StatCard extends StatelessWidget {
  final String emoji;
  final String value;
  final String label;
  const _StatCard({
    required this.emoji,
    required this.value,
    required this.label,
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
    decoration: BoxDecoration(
      color: AppColors.cardBg,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 22)),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.white,
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: const TextStyle(color: AppColors.mutedText, fontSize: 11),
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
}

class _EmptyTagsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: AppColors.cardBg,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppColors.border),
    ),
    child: const Column(
      children: [
        Text('🏷️', style: TextStyle(fontSize: 28)),
        SizedBox(height: 8),
        Text(
          'No tags selected yet.',
          style: TextStyle(color: AppColors.mutedText, fontSize: 14),
        ),
      ],
    ),
  );
}

// Compat shim so DietaryTagChip (which uses the old DietaryTag class) works
// with kFoodTags entries from the unified model.
class DietaryTagCompat {
  final String id;
  final String label;
  final String emoji;
  const DietaryTagCompat({
    required this.id,
    required this.label,
    required this.emoji,
  });
}
