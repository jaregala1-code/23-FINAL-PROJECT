// lib/screens/pantry/requesters_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/surplus_item.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/claim_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/pantry/base64_image.dart';
import '../qr/qr_scanner_screen.dart';

class RequestersPage extends StatefulWidget {
  final SurplusItem item;
  const RequestersPage({super.key, required this.item});

  @override
  State<RequestersPage> createState() => _RequestersPageState();
}

class _RequestersPageState extends State<RequestersPage> {
  bool _approving = false;
  String? _approvingUid;

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
          _ItemSummary(item: widget.item),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: Text(
              'Select ONE receiver to approve. All other pending requests will be automatically rejected.',
              style: TextStyle(
                color: AppColors.mutedText,
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: ClaimService.instance.streamRequesters(widget.item.id!),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppColors.yellow),
                  );
                }

                final all = snapshot.data ?? [];
                final pending = all
                    .where(
                      (r) => r['status'] == 'pending' || r['status'] == null,
                    )
                    .toList();
                final accepted = all
                    .where((r) => r['status'] == 'accepted')
                    .toList();

                if (pending.isEmpty && accepted.isEmpty) {
                  return const _EmptyRequesters();
                }

                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
                  children: [
                    if (accepted.isNotEmpty) ...[
                      const _SectionLabel('APPROVED'),
                      ...accepted.map(
                        (req) => _AcceptedCard(req: req, item: widget.item),
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (pending.isNotEmpty) ...[
                      _SectionLabel('PENDING (${pending.length})'),
                      ...pending.map(
                        (req) => _RequesterCard(
                          req: req,
                          item: widget.item,
                          isBusy: _approving,
                          busyForUid: _approvingUid,
                          onApprove: _onApprove,
                          disabled: accepted.isNotEmpty,
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onApprove(String requesterUid, String requesterName) async {
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
            color: AppColors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: const Text(
          'All other pending requesters will be notified that the item is no longer available.',
          style: TextStyle(color: AppColors.mutedText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.mutedText),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Approve'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (!mounted) return;

    setState(() {
      _approving = true;
      _approvingUid = requesterUid;
    });

    final myName = me.displayName.isNotEmpty ? me.displayName : me.email;
    final success = await ClaimService.instance.approveRequester(
      itemId: widget.item.id!,
      itemTitle: widget.item.title,
      ownerUid: me.uid,
      ownerName: myName,
      requesterUid: requesterUid,
      requesterName: requesterName,
    );

    if (!mounted) return;
    setState(() {
      _approving = false;
      _approvingUid = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Approved! A QR code has been generated.'
              : 'Something went wrong. Try again.',
        ),
        backgroundColor: success ? AppColors.green : AppColors.error,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
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

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.mutedText,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}

class _RequesterCard extends StatelessWidget {
  final Map<String, dynamic> req;
  final SurplusItem item;
  final bool isBusy;
  final String? busyForUid;
  final bool disabled;
  final Future<void> Function(String requesterUid, String requesterName)
  onApprove;

  const _RequesterCard({
    required this.req,
    required this.item,
    required this.isBusy,
    required this.busyForUid,
    required this.disabled,
    required this.onApprove,
  });

  @override
  Widget build(BuildContext context) {
    final name = req['requesterName'] as String? ?? 'Unknown';
    final uid = req['requesterUid'] as String? ?? req['id'] as String? ?? '';
    final photo = req['requesterPhotoBase64'] as String?;
    final showSpinner = isBusy && busyForUid == uid;

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
          _Avatar(name: name, photoBase64: photo),
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
          if (disabled)
            const Text(
              'Reserved',
              style: TextStyle(
                color: AppColors.mutedText,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            )
          else
            ElevatedButton(
              onPressed: (isBusy || uid.isEmpty)
                  ? null
                  : () => onApprove(uid, name),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(88, 36),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              child: showSpinner
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.black,
                      ),
                    )
                  : const Text('Approve', style: TextStyle(fontSize: 13)),
            ),
        ],
      ),
    );
  }
}

class _AcceptedCard extends StatelessWidget {
  final Map<String, dynamic> req;
  final SurplusItem item;

  const _AcceptedCard({required this.req, required this.item});

  @override
  Widget build(BuildContext context) {
    final name = req['requesterName'] as String? ?? 'Unknown';
    final photo = req['requesterPhotoBase64'] as String?;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.green.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Avatar(name: name, photoBase64: photo),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: AppColors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Approved — waiting for pickup',
                      style: TextStyle(color: AppColors.green, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => QRScannerScreen(item: item)),
              ),
              icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
              label: const Text('Scan Receiver QR'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String name;
  final String? photoBase64;
  const _Avatar({required this.name, this.photoBase64});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 24,
      backgroundColor: AppColors.green.withValues(alpha: 0.15),
      child: (photoBase64 != null && photoBase64!.isNotEmpty)
          ? ClipOval(
              child: Base64Image(
                base64: photoBase64!,
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
    );
  }
}

class _EmptyRequesters extends StatelessWidget {
  const _EmptyRequesters();

  @override
  Widget build(BuildContext context) {
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
}
