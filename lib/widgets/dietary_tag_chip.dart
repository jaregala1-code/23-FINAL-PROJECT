// lib/widgets/dietary_tag_chip.dart

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

// Minimal interface — any object with these three fields works.
abstract class TagLike {
  String get id;
  String get label;
  String get emoji;
}

class DietaryTagChip extends StatelessWidget {
  final dynamic tag; // accepts DietaryTag, DietaryTagCompat, or any TagLike
  final bool isSelected;
  final VoidCallback onTap;

  const DietaryTagChip({
    super.key,
    required this.tag,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.yellow : AppColors.cardBg2,
          borderRadius: BorderRadius.circular(50),
          border: Border.all(
            color: isSelected ? AppColors.yellow : AppColors.border,
            width: 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.yellow.withOpacity(0.25),
                    blurRadius: 12,
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(tag.emoji, style: const TextStyle(fontSize: 15)),
            const SizedBox(width: 6),
            Text(
              tag.label,
              style: TextStyle(
                color: isSelected ? AppColors.black : AppColors.white,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
