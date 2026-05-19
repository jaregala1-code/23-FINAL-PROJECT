// notifications_screen.dart
//
// Placeholder Notifications screen. Once the backend feed exists, swap the
// empty-state body for a [NotificationList] driven by a real data source.
// Planned notification triggers:
//   - Pantry items about to expire
//   - Claims on a user's listings
//   - Comments / likes on posts

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
      body: const _EmptyNotifications(),
    );
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
              'claims, or expiring pantry items.',
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

/// A reusable list widget for displaying notifications. Currently unused;
/// kept here so the screen can switch to it once a notifications data
/// source is wired up. Accepts a list of [NotificationItem]s and renders
/// each as a [ListTile].
class NotificationList extends StatelessWidget {
  final List<NotificationItem> items;

  const NotificationList({super.key, this.items = const []});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const _EmptyNotifications();
    }
    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, __) =>
          const Divider(height: 1, color: AppColors.border),
      itemBuilder: (context, index) {
        final n = items[index];
        return ListTile(
          leading: const Icon(
            Icons.notification_important,
            color: AppColors.green,
          ),
          title: Text(
            n.title,
            style: const TextStyle(
              color: AppColors.white,
              fontFamily: 'Sora',
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            n.body,
            style: const TextStyle(
              color: AppColors.mutedText,
              fontFamily: 'Sora',
            ),
          ),
        );
      },
    );
  }
}

/// Lightweight model for a single notification entry. Replace or extend
/// when the backend schema is finalized.
class NotificationItem {
  final String title;
  final String body;

  const NotificationItem({required this.title, required this.body});
}
