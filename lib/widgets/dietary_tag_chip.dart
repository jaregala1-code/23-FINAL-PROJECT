import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/dietary_tag.dart';

class DietaryTagChip extends StatelessWidget {
  final DietaryTag tag;
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
                    spreadRadius: 0,
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
                letterSpacing: 0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
