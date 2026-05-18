// lib/screens/pantry/tray_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/claim_service.dart';
import '../../theme/app_theme.dart';
import '../qr/qr_display_screen.dart';

class TrayScreen extends StatelessWidget {
  const TrayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<UserAuthProvider>();
    final myUid = authProvider.appUser?.uid ??
        context.watch<UserProvider>().user?.uid ?? '';

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: AppColors.darkBg,
        title: const Text('My Tray'),
      ),
      body: myUid.isEmpty
          ? const _EmptyTray()
          : StreamBuilder<List<Map<String, dynamic>>>(
              stream: ClaimService.instance.streamMyClaims(myUid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppColors.yellow),
                  );
                }

                final claims = snapshot.data ?? [];
                if (claims.isEmpty) return const _EmptyTray();

                final approved =
                    claims.where((c) => c['status'] == 'approved').toList();
                final pending =
                    claims.where((c) => c['status'] == 'pending').toList();

                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
                  children: [
                    if (approved.isNotEmpty) ...[
                      _SectionLabel(
                          '🎉 Approved — Ready for Pickup (${approved.length})'),
                      ...approved.map((c) => _ClaimCard(
                            claim: c,
                            myUid: myUid,
                          )),
                      const SizedBox(height: 16),
                    ],
                    if (pending.isNotEmpty) ...[
                      _SectionLabel(
                          'Pending Giver Response (${pending.length})'),
                      ...pending.map((c) => _ClaimCard(
                            claim: c,
                            myUid: myUid,
                          )),
                    ],
                  ],
                );
              },
            ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 4),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.mutedText,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _ClaimCard extends StatelessWidget {
  final Map<String, dynamic> claim;
  final String myUid;

  const _ClaimCard({required this.claim, required this.myUid});

  @override
  Widget build(BuildContext context) {
    final isApproved = claim['status'] == 'approved';
    final itemTitle = claim['itemTitle'] as String? ?? 'Item';
    final ownerName = claim['ownerName'] as String? ?? 'Giver';
    final qrToken = claim['qrToken'] as String?;
    final docId = claim['docId'] as String? ?? '';
    final itemId = claim['itemId'] as String? ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isApproved
              ? AppColors.green.withValues(alpha: 0.4)
              : AppColors.border,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.cardBg2,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Text('🍱', style: TextStyle(fontSize: 22)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        itemTitle,
                        style: const TextStyle(
                          color: AppColors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'From $ownerName',
                        style: const TextStyle(
                          color: AppColors.mutedText,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                _StatusBadge(isApproved: isApproved),
              ],
            ),

            if (isApproved && qrToken != null) ...[
              const SizedBox(height: 14),
              const Divider(color: AppColors.border, height: 1),
              const SizedBox(height: 14),
              const Text(
                'Show this QR code to your Giver at pickup.',
                style: TextStyle(color: AppColors.mutedText, fontSize: 13),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => QRDisplayScreen(
                        qrToken: qrToken,
                        itemTitle: itemTitle,
                        ownerName: ownerName,
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.qr_code_rounded, size: 18),
                  label: const Text('Show QR Code'),
                ),
              ),
            ] else if (!isApproved) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.hourglass_top_rounded,
                      size: 14, color: AppColors.mutedText),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text(
                      'Waiting for Giver to respond…',
                      style: TextStyle(
                        color: AppColors.mutedText,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => _confirmRemove(context, itemId, docId),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.error,
                      padding: EdgeInsets.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Remove',
                        style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _confirmRemove(
      BuildContext context, String itemId, String docId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        title: const Text('Remove from Tray?',
            style: TextStyle(color: AppColors.white, fontWeight: FontWeight.w600)),
        content: const Text(
          'Your claim request will be cancelled.',
          style: TextStyle(color: AppColors.mutedText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep',
                style: TextStyle(color: AppColors.mutedText)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (ok == true) {
      final authProvider = context.read<UserAuthProvider>();
      final uid = authProvider.appUser?.uid ?? '';
      await ClaimService.instance.cancelClaim(
        itemId: itemId,
        requesterUid: uid,
        claimDocId: docId,
      );
    }
  }
}

class _StatusBadge extends StatelessWidget {
  final bool isApproved;
  const _StatusBadge({required this.isApproved});

  @override
  Widget build(BuildContext context) {
    final color = isApproved ? AppColors.green : AppColors.yellow;
    final label = isApproved ? 'Approved' : 'Pending';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _EmptyTray extends StatelessWidget {
  const _EmptyTray();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Text('🛒', style: TextStyle(fontSize: 64)),
            SizedBox(height: 20),
            Text(
              'Your tray is empty',
              style: TextStyle(
                color: AppColors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Swipe right on items in the Pantry to claim them.',
              style: TextStyle(
                color: AppColors.mutedText,
                fontSize: 14,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
