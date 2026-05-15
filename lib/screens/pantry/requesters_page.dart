// lib/screens/pantry/requesters_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/surplus_item.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/claim_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/pantry/base64_image.dart';

class RequestersPage extends StatelessWidget {
  final SurplusItem item;
  const RequestersPage({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: AppColors.darkBg,
        title: const Text('Requesters'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Item summary card
          _ItemSummary(item: item),

          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: Text(
              'Select ONE receiver to approve. All other pending requests will be automatically rejected.',
              style: const TextStyle(
                color: AppColors.mutedText,
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ),

          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: ClaimService.instance.streamRequesters(item.id!),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppColors.yellow),
                  );
                }

                final requesters = (snapshot.data ?? [])
                    .where((r) =>
                        r['status'] == 'pending' || r['status'] == null)
                    .toList();

                if (requesters.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Text('👀', style: TextStyle(fontSize: 52)),
                          SizedBox(height: 16),
                          Text(
                            'No requesters yet',
                            style: TextStyle(
                              color: AppColors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Community members nearby will see your listing soon.',
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

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
                  itemCount: requesters.length,
                  itemBuilder: (context, i) {
                    final req = requesters[i];
                    return _RequesterCard(
                      req: req,
                      item: item,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemSummary extends StatelessWidget {
  final SurplusItem item;
  const _ItemSummary({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: item.photoBase64.isNotEmpty
                ? Base64Image(
                    base64: item.photoBase64,
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                  )
                : Container(
                    width: 56,
                    height: 56,
                    color: AppColors.cardBg2,
                    child: const Center(
                      child: Text('🍽️', style: TextStyle(fontSize: 22)),
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    color: AppColors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                Text(
                  item.quantity,
                  style: const TextStyle(
                    color: AppColors.mutedText,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RequesterCard extends StatelessWidget {
  final Map<String, dynamic> req;
  final SurplusItem item;

  const _RequesterCard({required this.req, required this.item});

  @override
  Widget build(BuildContext context) {
    final name = req['requesterName'] as String? ?? 'Unknown';
    final uid = req['requesterUid'] as String? ?? req['id'] as String? ?? '';
    final photo = req['requesterPhotoBase64'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.green.withValues(alpha: 0.15),
            child: photo != null
                ? ClipOval(
                    child: Base64Image(
                      base64: photo,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                    ),
                  )
                : Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: const TextStyle(
                      color: AppColors.green,
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(
                color: AppColors.white,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => _confirmApprove(context, uid, name),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(80, 36),
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            child: const Text(
              'Approve',
              style: TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmApprove(
      BuildContext context, String requesterUid, String requesterName) async {
    final authProvider = context.read<UserAuthProvider>();
    final userProvider = context.read<UserProvider>();
    final me = authProvider.appUser ?? userProvider.user;
    if (me == null) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        title: Text(
          'Approve $requesterName?',
          style: const TextStyle(
              color: AppColors.white, fontWeight: FontWeight.w600),
        ),
        content: const Text(
          'All other pending requesters will be notified that the item is no longer available.',
          style: TextStyle(color: AppColors.mutedText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.mutedText)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Approve'),
          ),
        ],
      ),
    );

    if (ok == true) {
      final myName = me.displayName.isNotEmpty ? me.displayName : me.email;
      final success = await ClaimService.instance.approveRequester(
        itemId: item.id!,
        itemTitle: item.title,
        ownerUid: me.uid,
        ownerName: myName,
        requesterUid: requesterUid,
        requesterName: requesterName,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success
                ? 'Approved! A QR code has been generated.'
                : 'Something went wrong. Try again.'),
            backgroundColor:
                success ? AppColors.green : AppColors.error,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            behavior: SnackBarBehavior.floating,
          ),
        );
        if (success) Navigator.pop(context);
      }
    }
  }
}
