// lib/widgets/pantry/swipe_card.dart

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/surplus_item.dart';
import '../../theme/app_theme.dart';
import 'base64_image.dart';

class SwipeCard extends StatelessWidget {
  final SurplusItem item;
  final double dragX;
  final bool isBack;

  const SwipeCard({
    super.key,
    required this.item,
    required this.dragX,
    required this.isBack,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background photo
          _buildPhoto(),

          // Dark gradient overlay (bottom)
          _buildGradient(),

          // Swipe direction overlays
          if (!isBack && dragX > 20) _buildSwipeOverlay(true),
          if (!isBack && dragX < -20) _buildSwipeOverlay(false),

          // Content at bottom
          if (!isBack) _buildContent(context),
        ],
      ),
    );
  }

  Widget _buildPhoto() {
    return item.photoBase64.isNotEmpty
        ? Base64Image(
            base64: item.photoBase64,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          )
        : Container(
            color: AppColors.cardBg2,
            child: const Center(
              child: Text('🍽️', style: TextStyle(fontSize: 72)),
            ),
          );
  }

  Widget _buildGradient() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: [0.4, 1.0],
          colors: [Colors.transparent, Colors.black87],
        ),
      ),
    );
  }

  Widget _buildSwipeOverlay(bool isRight) {
    final opacity = (dragX.abs() / 120).clamp(0.0, 1.0);
    return Positioned(
      top: 28,
      left: isRight ? 20 : null,
      right: isRight ? null : 20,
      child: Opacity(
        opacity: opacity,
        child: Transform.rotate(
          angle: isRight ? -0.18 : 0.18,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              border: Border.all(
                color: isRight ? AppColors.green : AppColors.error,
                width: 3,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              isRight ? 'TRAY' : 'PASS',
              style: TextStyle(
                color: isRight ? AppColors.green : AppColors.error,
                fontWeight: FontWeight.w800,
                fontSize: 26,
                letterSpacing: 2,
                fontFamily: 'Sora',
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final daysLeft = item.expirationDate.difference(DateTime.now()).inDays;
    final hoursLeft = item.expirationDate.difference(DateTime.now()).inHours;
    final timeLabel = daysLeft > 0
        ? '${daysLeft}d left'
        : hoursLeft > 0
            ? '${hoursLeft}h left'
            : 'Expiring soon';
    final isAlmostGone = daysLeft < 1;

    return Positioned(
      left: 16,
      right: 16,
      bottom: 14,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tags
          if (item.tags.isNotEmpty)
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: item.tags.take(3).map((tag) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    tag,
                    style: const TextStyle(
                      color: AppColors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              }).toList(),
            ),
          const SizedBox(height: 8),

          // Item name
          Text(
            item.title,
            style: const TextStyle(
              color: AppColors.white,
              fontSize: 26,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),

          // Quantity + description
          if (item.description.isNotEmpty)
            Text(
              item.description,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          const SizedBox(height: 8),

          // Meta row
          Row(
            children: [
              // Owner
              CircleAvatar(
                radius: 11,
                backgroundColor: AppColors.green,
                child: Text(
                  item.ownerName.isNotEmpty
                      ? item.ownerName[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                item.ownerName,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),

              // Expiry badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: isAlmostGone
                      ? AppColors.orange
                      : Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.access_time_rounded,
                      size: 11,
                      color: AppColors.white,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      timeLabel,
                      style: const TextStyle(
                        color: AppColors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Quantity
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.green.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  item.quantity,
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
