// lib/screens/pantry/food_detail_sheet.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/surplus_item.dart';
import '../../theme/app_theme.dart';
import '../../widgets/pantry/base64_image.dart';

class FoodDetailSheet extends StatelessWidget {
  final SurplusItem item;
  final VoidCallback onAddToTray;
  final VoidCallback onPass;

  const FoodDetailSheet({
    super.key,
    required this.item,
    required this.onAddToTray,
    required this.onPass,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: EdgeInsets.zero,
                  children: [
                    // Photo
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(24)),
                      child: item.photoBase64.isNotEmpty
                          ? Base64Image(
                              base64: item.photoBase64,
                              height: 240,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            )
                          : Container(
                              height: 240,
                              color: AppColors.cardBg2,
                              child: const Center(
                                child: Text('🍽️',
                                    style: TextStyle(fontSize: 64)),
                              ),
                            ),
                    ),

                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Title + quantity
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  item.title,
                                  style: const TextStyle(
                                    color: AppColors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.4,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppColors.green.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                      color: AppColors.green.withOpacity(0.4)),
                                ),
                                child: Text(
                                  item.quantity,
                                  style: const TextStyle(
                                    color: AppColors.green,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          if (item.description.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Text(
                              item.description,
                              style: const TextStyle(
                                color: AppColors.mutedText,
                                fontSize: 14,
                                height: 1.5,
                              ),
                            ),
                          ],

                          const SizedBox(height: 16),
                          const Divider(color: AppColors.border, height: 1),
                          const SizedBox(height: 16),

                          // Info rows
                          _InfoRow(
                            icon: Icons.schedule_outlined,
                            label: 'Best before',
                            value: DateFormat('MMM d, yyyy – h:mm a')
                                .format(item.expirationDate),
                            urgent: item.expirationDate
                                .difference(DateTime.now())
                                .inDays < 1,
                          ),
                          const SizedBox(height: 10),

                          // Tags
                          if (item.tags.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: item.tags.map((tag) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: AppColors.cardBg2,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                        color: AppColors.border),
                                  ),
                                  child: Text(
                                    tag,
                                    style: const TextStyle(
                                      color: AppColors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 16),
                          ],

                          const Divider(color: AppColors.border, height: 1),
                          const SizedBox(height: 16),

                          // Giver info
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 22,
                                backgroundColor:
                                    AppColors.green.withOpacity(0.15),
                                child: Text(
                                  item.ownerName.isNotEmpty
                                      ? item.ownerName[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    color: AppColors.green,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.ownerName,
                                    style: const TextStyle(
                                      color: AppColors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const Text(
                                    'Giver',
                                    style: TextStyle(
                                      color: AppColors.mutedText,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),

                          const SizedBox(height: 28),

                          // CTA buttons
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: onAddToTray,
                              icon: const Icon(
                                  Icons.shopping_basket_outlined,
                                  size: 18),
                              label: const Text('Add to Tray'),
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: onPass,
                              child: const Text('Pass'),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool urgent;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.urgent = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon,
            size: 16,
            color: urgent ? AppColors.orange : AppColors.mutedText),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                  color: AppColors.mutedText, fontSize: 11),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                color: urgent ? AppColors.orange : AppColors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
