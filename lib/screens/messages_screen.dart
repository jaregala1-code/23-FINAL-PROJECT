import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_theme.dart';

/// Status of a food claim/request
enum ClaimStatus { pending, accepted, readyForPickup, completed, cancelled }

/// Data model for a food claim (used for dummy data)
class FoodClaim {
  final String id;
  final String foodName;
  final String foodEmoji;
  final String ownerName;
  final String pickupLocation;
  final ClaimStatus status;
  final DateTime requestedAt;

  const FoodClaim({
    required this.id,
    required this.foodName,
    required this.foodEmoji,
    required this.ownerName,
    required this.pickupLocation,
    required this.status,
    required this.requestedAt,
  });
}

class MessagesScreen extends StatelessWidget {
  final User firebaseUser;

  const MessagesScreen({super.key, required this.firebaseUser});

  // ── Dummy data ──
  // TODO: Replace _dummyClaims with a Firestore query.
  //
  // Query pattern (once you have an "items" or "requests" collection):
  //
  //   FirebaseFirestore.instance
  //       .collection('requests')
  //       .where('requesterUid', isEqualTo: firebaseUser.uid)
  //       .orderBy('requestedAt', descending: true)
  //       .snapshots()
  //
  // Map each document to a FoodClaim (or your own model) and
  // display it in place of the dummy list below.

  static final List<FoodClaim> _dummyClaims = [
    FoodClaim(
      id: '1',
      foodName: 'Leftover Kare-kare',
      foodEmoji: '🍱',
      ownerName: 'Maria Santos',
      pickupLocation: 'UP Diliman, Krus na Ligas Gate',
      status: ClaimStatus.readyForPickup,
      requestedAt: DateTime.now().subtract(const Duration(minutes: 30)),
    ),
    FoodClaim(
      id: '2',
      foodName: 'Sourdough Loaf',
      foodEmoji: '🥖',
      ownerName: 'Juan dela Cruz',
      pickupLocation: 'Katipunan Ave, near 7-Eleven',
      status: ClaimStatus.pending,
      requestedAt: DateTime.now().subtract(const Duration(hours: 2)),
    ),
    FoodClaim(
      id: '3',
      foodName: 'Extra Adobo Rice',
      foodEmoji: '🍛',
      ownerName: 'Ana Reyes',
      pickupLocation: 'Maginhawa St, Teacher\'s Village',
      status: ClaimStatus.completed,
      requestedAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
    FoodClaim(
      id: '4',
      foodName: 'Fresh Mangoes (x4)',
      foodEmoji: '🥭',
      ownerName: 'Carlos Mendoza',
      pickupLocation: 'Esteban Abada St, Loyola Heights',
      status: ClaimStatus.accepted,
      requestedAt: DateTime.now().subtract(const Duration(days: 1, hours: 3)),
    ),
    FoodClaim(
      id: '5',
      foodName: 'Pancit Canton Leftovers',
      foodEmoji: '🍜',
      ownerName: 'Rosa Lim',
      pickupLocation: 'Commonwealth Ave, near SM North',
      status: ClaimStatus.cancelled,
      requestedAt: DateTime.now().subtract(const Duration(days: 3)),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    // TODO: Replace this with a StreamBuilder once Firestore is ready.
    //
    // Example StreamBuilder scaffold:
    //
    //   return StreamBuilder<QuerySnapshot>(
    //     stream: FirebaseFirestore.instance
    //         .collection('requests')
    //         .where('requesterUid', isEqualTo: firebaseUser.uid)
    //         .orderBy('requestedAt', descending: true)
    //         .snapshots(),
    //     builder: (context, snapshot) {
    //       if (snapshot.connectionState == ConnectionState.waiting) {
    //         return const Center(child: CircularProgressIndicator(color: AppColors.yellow));
    //       }
    //       if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
    //         return _EmptyState();
    //       }
    //       final claims = snapshot.data!.docs
    //           .map((doc) => FoodClaim.fromMap(doc.data() as Map<String, dynamic>, doc.id))
    //           .toList();
    //       return _ClaimList(claims: claims);
    //     },
    //   );

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: AppColors.darkBg,
        title: const Text('My Requests'),
        centerTitle: false,
      ),
      body: _dummyClaims.isEmpty
          ? const _EmptyState()
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
              itemCount: _dummyClaims.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) => _ClaimCard(claim: _dummyClaims[i]),
            ),
    );
  }
}

// ── Claim card ──

class _ClaimCard extends StatelessWidget {
  final FoodClaim claim;
  const _ClaimCard({required this.claim});

  @override
  Widget build(BuildContext context) {
    final status = _statusMeta(claim.status);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: claim.status == ClaimStatus.readyForPickup
              ? AppColors.green.withValues(alpha: 0.4)
              : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              // Emoji
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.cardBg2,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    claim.foodEmoji,
                    style: const TextStyle(fontSize: 22),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      claim.foodName,
                      style: const TextStyle(
                        color: AppColors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'From ${claim.ownerName}',
                      style: const TextStyle(
                        color: AppColors.mutedText,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              // Status badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: status.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(50),
                ),
                child: Text(
                  status.label,
                  style: TextStyle(
                    color: status.color,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 10),

          // Location row
          Row(
            children: [
              const Icon(
                Icons.location_on_outlined,
                size: 13,
                color: AppColors.mutedText,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  claim.pickupLocation,
                  style: const TextStyle(
                    color: AppColors.mutedText,
                    fontSize: 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Time row
          Row(
            children: [
              const Icon(
                Icons.schedule_rounded,
                size: 13,
                color: AppColors.mutedText,
              ),
              const SizedBox(width: 5),
              Text(
                _timeAgo(claim.requestedAt),
                style: const TextStyle(
                  color: AppColors.mutedText,
                  fontSize: 12,
                ),
              ),
              const Spacer(),
              // Status icon hint
              Icon(status.icon, size: 13, color: status.color),
              const SizedBox(width: 4),
              Text(
                status.hint,
                style: TextStyle(
                  color: status.color,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return 'Requested ${diff.inMinutes}m ago';
    if (diff.inHours < 24) return 'Requested ${diff.inHours}h ago';
    return 'Requested ${diff.inDays}d ago';
  }

  _StatusMeta _statusMeta(ClaimStatus status) {
    switch (status) {
      case ClaimStatus.pending:
        return _StatusMeta(
          label: 'Pending',
          color: AppColors.yellow,
          icon: Icons.hourglass_top_rounded,
          hint: 'Awaiting owner reply',
        );
      case ClaimStatus.accepted:
        return _StatusMeta(
          label: 'Accepted',
          color: AppColors.green,
          icon: Icons.check_circle_outline_rounded,
          hint: 'Request accepted',
        );
      case ClaimStatus.readyForPickup:
        return _StatusMeta(
          label: 'Ready for Pickup',
          color: AppColors.green,
          icon: Icons.directions_walk_rounded,
          hint: 'Go pick it up!',
        );
      case ClaimStatus.completed:
        return _StatusMeta(
          label: 'Completed',
          color: AppColors.mutedText,
          icon: Icons.task_alt_rounded,
          hint: 'Transaction done',
        );
      case ClaimStatus.cancelled:
        return _StatusMeta(
          label: 'Cancelled',
          color: const Color(0xFFcf6679),
          icon: Icons.cancel_outlined,
          hint: 'Claim was cancelled',
        );
    }
  }
}

class _StatusMeta {
  final String label;
  final Color color;
  final IconData icon;
  final String hint;
  const _StatusMeta({
    required this.label,
    required this.color,
    required this.icon,
    required this.hint,
  });
}

// ── Empty state ──

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Text('📭', style: TextStyle(fontSize: 52)),
            SizedBox(height: 16),
            Text(
              'No requests yet',
              style: TextStyle(
                color: AppColors.white,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'When you claim or request food from other\nusers, they will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.mutedText,
                fontSize: 14,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
