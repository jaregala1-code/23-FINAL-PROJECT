// lib/widgets/pantry/item_card.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/surplus_item.dart';
import '../../providers/pantry_provider.dart';
import '../../providers/user_provider.dart';
import '../../screens/pantry/add_item_screen.dart';
import '../../theme/app_theme.dart';
import 'base64_image.dart';
import 'item_status_chip.dart';

class ItemCard extends StatelessWidget {
  const ItemCard({super.key, required this.item});
  final SurplusItem item;

  @override
  Widget build(BuildContext context) {
    final uid = context.read<UserProvider>().user?.uid ?? '';
    final isOwner = item.ownerUid == uid;
    final expiry = DateFormat('MMM d, yyyy').format(item.expirationDate);
    final days = item.expirationDate.difference(DateTime.now()).inDays;
    final expiryColor = days <= 1
        ? Colors.redAccent
        : days <= 3
        ? AppColors.orange
        : AppColors.mutedText;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Photo
          Base64Image(
            base64: item.photoBase64,
            height: 160,
            width: double.infinity,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
          ),

          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title + status
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.title,
                        style: const TextStyle(
                          color: AppColors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    ItemStatusChip(status: item.status),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  item.quantity,
                  style: const TextStyle(
                    color: AppColors.mutedText,
                    fontSize: 12,
                  ),
                ),
                if (item.description.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    item.description,
                    style: const TextStyle(
                      color: AppColors.mutedText,
                      fontSize: 12,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 10),

                // Expiry row
                Row(
                  children: [
                    Icon(Icons.schedule, size: 13, color: expiryColor),
                    const SizedBox(width: 4),
                    Text(
                      'Expires $expiry',
                      style: TextStyle(
                        color: expiryColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'by ${item.ownerName}',
                      style: const TextStyle(
                        color: AppColors.mutedText,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Actions
                _ItemActions(item: item, isOwner: isOwner),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Actions ───────────────────────────────────────────────────────────────────

class _ItemActions extends StatelessWidget {
  const _ItemActions({required this.item, required this.isOwner});
  final SurplusItem item;
  final bool isOwner;

  @override
  Widget build(BuildContext context) {
    if (isOwner) return _ownerActions(context);
    if (item.status == ItemStatus.available) return _requestButton(context);
    return Text(
      item.status == ItemStatus.reserved
          ? 'Reserved by ${item.claimedByName}'
          : 'Exchange Completed ✓',
      style: const TextStyle(color: AppColors.mutedText, fontSize: 12),
    );
  }

  Widget _ownerActions(BuildContext context) => Row(
    children: [
      Expanded(
        child: OutlinedButton.icon(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AddItemScreen(existingItem: item),
            ),
          ),
          icon: const Icon(
            Icons.edit_outlined,
            size: 14,
            color: AppColors.mutedText,
          ),
          label: const Text(
            'Edit',
            style: TextStyle(fontSize: 12, color: AppColors.mutedText),
          ),
          style: _outlineStyle(),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: OutlinedButton.icon(
          onPressed: () => _confirmDelete(context),
          icon: const Icon(
            Icons.delete_outline,
            size: 14,
            color: Color(0xFFcf6679),
          ),
          label: const Text(
            'Delete',
            style: TextStyle(fontSize: 12, color: Color(0xFFcf6679)),
          ),
          style: _outlineStyle(color: const Color(0xFFcf6679)),
        ),
      ),
    ],
  );

  Widget _requestButton(BuildContext context) => SizedBox(
    width: double.infinity,
    child: ElevatedButton.icon(
      onPressed: () => _sendRequest(context),
      icon: const Icon(Icons.volunteer_activism, size: 14),
      label: const Text('Request', style: TextStyle(fontSize: 12)),
    ),
  );

  Future<void> _confirmDelete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        title: const Text(
          'Delete Item?',
          style: TextStyle(color: AppColors.white, fontWeight: FontWeight.w600),
        ),
        content: const Text(
          'This will permanently remove the posting.',
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
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Color(0xFFcf6679)),
            ),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await context.read<PantryProvider>().deleteItem(item.id!);
    }
  }

  Future<void> _sendRequest(BuildContext context) async {
    final user = context.read<UserProvider>().user!;
    await context.read<PantryProvider>().requestItem(
      itemId: item.id!,
      requesterUid: user.uid,
      requesterName: user.displayName.isNotEmpty
          ? user.displayName
          : user.email,
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Request sent! Waiting for the owner to accept.'),
        ),
      );
    }
  }

  ButtonStyle _outlineStyle({Color? color}) => OutlinedButton.styleFrom(
    padding: const EdgeInsets.symmetric(vertical: 8),
    side: BorderSide(color: color ?? AppColors.border),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
  );
}
