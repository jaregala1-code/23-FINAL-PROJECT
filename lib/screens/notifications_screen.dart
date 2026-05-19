// lib/screens/notifications_screen.dart
//

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/app_notification.dart';
import '../providers/notification_provider.dart';
import '../theme/app_theme.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<NotificationProvider>();
      if (provider.hasUnread) {
        provider.markAllRead();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final notifs = context.watch<NotificationProvider>().items;

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: AppColors.darkBg,
        foregroundColor: AppColors.white,
        title: const Text(
          'Notifications',
          style: TextStyle(
            color: AppColors.white,
            fontFamily: 'Sora',
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: notifs.isEmpty
          ? const _EmptyNotifications()
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: notifs.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, color: AppColors.border),
              itemBuilder: (context, i) => _NotificationTile(item: notifs[i]),
            ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final AppNotification item;

  const _NotificationTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final accent = _accentFor(item.type);
    return InkWell(
      onTap: () {
        if (!item.read) {
          context.read<NotificationProvider>().markRead(item.id);
        }
      },
      child: Container(
        color: item.read
            ? Colors.transparent
            : AppColors.green.withValues(alpha: 0.06),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Icon(_iconFor(item.type), color: accent, size: 18),
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
                          style: TextStyle(
                            color: AppColors.white,
                            fontFamily: 'Sora',
                            fontWeight: item.read
                                ? FontWeight.w500
                                : FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _relativeTime(item.createdAt),
                        style: const TextStyle(
                          color: AppColors.mutedText,
                          fontSize: 11,
                          fontFamily: 'Sora',
                        ),
                      ),
                    ],
                  ),
                  if (item.body.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      item.body,
                      style: const TextStyle(
                        color: AppColors.mutedText,
                        fontFamily: 'Sora',
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (!item.read)
              Padding(
                padding: const EdgeInsets.only(left: 8, top: 6),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.green,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  static IconData _iconFor(AppNotificationType t) {
    switch (t) {
      case AppNotificationType.claimRequested:
        return Icons.front_hand_outlined;
      case AppNotificationType.claimApproved:
        return Icons.check_circle_outline_rounded;
      case AppNotificationType.claimRejected:
        return Icons.cancel_outlined;
      case AppNotificationType.claimCancelled:
        return Icons.remove_circle_outline_rounded;
      case AppNotificationType.claimCompleted:
        return Icons.handshake_outlined;
      case AppNotificationType.pickupScheduled:
        return Icons.schedule_outlined;
      case AppNotificationType.message:
        return Icons.chat_bubble_outline_rounded;
    }
  }

  static Color _accentFor(AppNotificationType t) {
    switch (t) {
      case AppNotificationType.claimApproved:
      case AppNotificationType.claimCompleted:
        return AppColors.green;
      case AppNotificationType.claimRejected:
      case AppNotificationType.claimCancelled:
        return AppColors.error;
      case AppNotificationType.pickupScheduled:
      case AppNotificationType.claimRequested:
      case AppNotificationType.message:
        return AppColors.yellow;
    }
  }

  static String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return DateFormat('MMM d').format(dt);
  }
}

class _EmptyNotifications extends StatelessWidget {
  const _EmptyNotifications();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(
              Icons.notifications_off_outlined,
              size: 64,
              color: AppColors.mutedText,
            ),
            SizedBox(height: 16),
            Text(
              'No notifications yet',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.white,
                fontFamily: 'Sora',
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 8),
            Text(
              "We'll let you know when there's activity on your posts, "
              'claims, or messages.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.mutedText,
                fontFamily: 'Sora',
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
