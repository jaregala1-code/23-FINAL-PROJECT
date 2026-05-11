// lib/widgets/profile/verification_badge_widget.dart

import 'package:flutter/material.dart';
import '../../models/app_user.dart';
import '../../theme/app_theme.dart';

class VerificationBadgeWidget extends StatelessWidget {
  const VerificationBadgeWidget({super.key, required this.status});
  final VerificationStatus status;

  @override
  Widget build(BuildContext context) {
    final cfg = _cfg(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: cfg.color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cfg.color.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(cfg.icon, size: 13, color: cfg.color),
          const SizedBox(width: 4),
          Text(
            cfg.label,
            style: TextStyle(
              color: cfg.color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  _Cfg _cfg(VerificationStatus s) {
    switch (s) {
      case VerificationStatus.verified:
        return _Cfg(Icons.verified, AppColors.green, 'Verified');
      case VerificationStatus.pending:
        return _Cfg(Icons.hourglass_top, AppColors.orange, 'Pending Review');
      case VerificationStatus.rejected:
        return _Cfg(Icons.cancel, const Color(0xFFcf6679), 'Rejected');
      default:
        return _Cfg(Icons.shield_outlined, AppColors.mutedText, 'Unverified');
    }
  }
}

class _Cfg {
  const _Cfg(this.icon, this.color, this.label);
  final IconData icon;
  final Color color;
  final String label;
}
