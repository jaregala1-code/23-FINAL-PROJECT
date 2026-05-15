// lib/screens/pantry/add_item_screen.dart
//
// "Post" tab — shows the Giver's active listings first,
// then a "+ Post New Item" button at bottom.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/surplus_item.dart';
import '../../providers/pantry_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/pantry_service.dart';
import '../../services/claim_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/pantry/base64_image.dart';
import '../../widgets/pantry/item_status_chip.dart';
import '../qr/qr_scanner_screen.dart';
import 'requesters_page.dart';
import 'create_listing_sheet.dart';

class AddItemScreen extends StatelessWidget {
  const AddItemScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<UserAuthProvider>();
    final userProvider = context.watch<UserProvider>();
    final myUid =
        authProvider.appUser?.uid ?? userProvider.user?.uid ?? '';
    final pantry = context.watch<PantryProvider>();

    final myItems =
        pantry.items.where((i) => i.ownerUid == myUid).toList();
    final active = myItems.where((i) => i.status == ItemStatus.available).toList();
    final reserved = myItems.where((i) => i.status == ItemStatus.reserved).toList();
    final completed = myItems.where((i) => i.status == ItemStatus.completed).toList();

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: AppColors.darkBg,
        title: const Text('My Pantry'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openCreateSheet(context),
        backgroundColor: AppColors.yellow,
        foregroundColor: AppColors.black,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Post Food',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: myItems.isEmpty
          ? _buildEmpty(context)
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              children: [
                if (active.isNotEmpty) ...[
                  _SectionHeader('Active (${active.length})'),
                  ...active.map((i) => _ListingCard(item: i)),
                ],
                if (reserved.isNotEmpty) ...[
                  _SectionHeader('Reserved (${reserved.length})'),
                  ...reserved.map((i) => _ListingCard(item: i)),
                ],
                if (completed.isNotEmpty) ...[
                  _SectionHeader('Completed (${completed.length})'),
                  ...completed.map((i) => _ListingCard(item: i)),
                ],
              ],
            ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🍱', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 20),
            const Text(
              'Nothing posted yet',
              style: TextStyle(
                color: AppColors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Share your surplus food with the Elbi community!',
              style: TextStyle(
                color: AppColors.mutedText,
                fontSize: 14,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: () => _openCreateSheet(context),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Post Your First Item'),
            ),
          ],
        ),
      ),
    );
  }

  void _openCreateSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const CreateListingSheet(),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 12),
      child: Text(
        text.toUpperCase(),
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

class _ListingCard extends StatelessWidget {
  final SurplusItem item;
  const _ListingCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final isActive = item.status == ItemStatus.available;
    final isReserved = item.status == ItemStatus.reserved;

    return GestureDetector(
      onTap: () {
        if (isActive && item.id != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => RequestersPage(item: item)),
          );
        } else if (isReserved) {
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => QRScannerScreen(item: item)),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Photo
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: item.photoBase64.isNotEmpty
                    ? Base64Image(
                        base64: item.photoBase64,
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
                      )
                    : Container(
                        width: 72,
                        height: 72,
                        color: AppColors.cardBg2,
                        child: const Center(
                          child: Text('🍽️',
                              style: TextStyle(fontSize: 28)),
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: const TextStyle(
                              color: AppColors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
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
                          color: AppColors.mutedText, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Expires ${DateFormat('MMM d').format(item.expirationDate)}',
                      style: const TextStyle(
                          color: AppColors.mutedText, fontSize: 12),
                    ),
                    if (isActive) ...[
                      const SizedBox(height: 4),
                      const Text(
                        'Tap to view requesters →',
                        style: TextStyle(
                          color: AppColors.yellow,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ] else if (isReserved) ...[
                      const SizedBox(height: 4),
                      const Text(
                        'Tap to scan QR Code →',
                        style: TextStyle(
                          color: AppColors.green,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
