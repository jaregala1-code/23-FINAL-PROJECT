// lib/widgets/pantry/item_status_chip.dart

import 'package:flutter/material.dart';
import '../../models/surplus_item.dart';
import '../../theme/app_theme.dart';

class ItemStatusChip extends StatelessWidget {
  const ItemStatusChip({super.key, required this.status});
  final ItemStatus status;

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    switch (status) {
      case ItemStatus.reserved:
        color = AppColors.orange;
        label = 'Reserved';
        break;
      case ItemStatus.completed:
        color = AppColors.green;
        label = 'Completed';
        break;
      default:
        color = AppColors.yellow;
        label = 'Available';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
