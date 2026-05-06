import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../models/dietary_tag.dart';
import '../widgets/dietary_tag_chip.dart';

class ProfileScreen extends StatelessWidget {
  final User firebaseUser;

  const ProfileScreen({super.key, required this.firebaseUser});

  @override
  Widget build(BuildContext context) {
    final appUser = context.watch<UserAuthProvider>().appUser;

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: CustomScrollView(
        slivers: [
          // ── Sliver App Bar ──
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            backgroundColor: AppColors.darkBg,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Gradient background
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF1a2e14), AppColors.darkBg],
                      ),
                    ),
                  ),
                  // Green accent blob
                  Positioned(
                    top: -40,
                    right: -40,
                    child: Container(
                      width: 180,
                      height: 180,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.green.withOpacity(0.1),
                      ),
                    ),
                  ),
                  // Avatar + name
                  Positioned(
                    bottom: 24,
                    left: 24,
                    right: 24,
                    child: Row(
                      children: [
                        // Avatar
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.green,
                            border: Border.all(
                              color: AppColors.yellow,
                              width: 2.5,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              appUser != null
                                  ? appUser.firstName[0].toUpperCase()
                                  : (firebaseUser.displayName?[0]
                                            .toUpperCase() ??
                                        'U'),
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: AppColors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                appUser?.displayName ??
                                    firebaseUser.displayName ??
                                    'Community Member',
                                style: const TextStyle(
                                  color: AppColors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.green.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          appUser?.isVerified == true
                                              ? Icons.verified_rounded
                                              : Icons.pending_outlined,
                                          size: 12,
                                          color: appUser?.isVerified == true
                                              ? AppColors.green
                                              : AppColors.mutedText,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          appUser?.isVerified == true
                                              ? 'Verified'
                                              : 'Unverified',
                                          style: TextStyle(
                                            color: appUser?.isVerified == true
                                                ? AppColors.green
                                                : AppColors.mutedText,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(
                  Icons.edit_outlined,
                  color: AppColors.white,
                  size: 20,
                ),
                onPressed: () {
                  // TODO: Edit profile
                },
              ),
              IconButton(
                icon: const Icon(
                  Icons.logout_rounded,
                  color: AppColors.mutedText,
                  size: 20,
                ),
                onPressed: () => context.read<UserAuthProvider>().signOut(),
                tooltip: 'Sign out',
              ),
            ],
          ),

          // ── Body ──
          SliverPadding(
            padding: const EdgeInsets.all(24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ── Info Card ──
                _SectionCard(
                  child: Column(
                    children: [
                      _InfoRow(
                        icon: Icons.person_outline_rounded,
                        label: 'Full Name',
                        value: appUser != null
                            ? '${appUser.firstName} ${appUser.lastName}'
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
                        value: appUser?.displayName ?? '—',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ── Dietary Tags ──
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
                    if (appUser != null && appUser.dietaryTags.isNotEmpty)
                      Text(
                        '${appUser.dietaryTags.length} selected',
                        style: const TextStyle(
                          color: AppColors.mutedText,
                          fontSize: 13,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                if (appUser == null || appUser.dietaryTags.isEmpty)
                  _EmptyTagsCard()
                else
                  _SectionCard(
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: AppTags.dietary
                            .where((t) => appUser.dietaryTags.contains(t.id))
                            .map(
                              (tag) => DietaryTagChip(
                                tag: tag,
                                isSelected: true,
                                onTap: () {},
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ),
                const SizedBox(height: 20),

                // ── Stats Row ──
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        emoji: '🥡',
                        value: '0',
                        label: 'Items Shared',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        emoji: '🤝',
                        value: '0',
                        label: 'Claims Made',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(emoji: '⭐', value: '—', label: 'Rating'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // ── Verification Banner ──
                if (appUser?.isVerified != true)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.orange.withOpacity(0.12),
                          AppColors.yellow.withOpacity(0.08),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: AppColors.orange.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Text('📸', style: TextStyle(fontSize: 28)),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
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
                        const SizedBox(width: 8),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 14,
                          color: AppColors.orange,
                        ),
                      ],
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

// ── Reusable sub-widgets ──

class _SectionCard extends StatelessWidget {
  final Widget child;
  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
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
  Widget build(BuildContext context) {
    return Padding(
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
                style: const TextStyle(
                  color: AppColors.mutedText,
                  fontSize: 11,
                ),
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
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, color: AppColors.border);
  }
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
  Widget build(BuildContext context) {
    return Container(
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
}

class _EmptyTagsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: const [
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
}
