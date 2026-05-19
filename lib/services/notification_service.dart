// lib/services/notification_service.dart
//

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/app_notification.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const String _col = 'notifications';

  /// Recent notifications for the given user, newest first.
  /// Capped to 100 to keep client memory bounded.
  Stream<List<AppNotification>> streamForUser(String uid, {int limit = 100}) {
    return _db
        .collection(_col)
        .where('userUid', isEqualTo: uid)
        .snapshots()
        .map((snap) {
          final list = snap.docs.map(AppNotification.fromFirestore).toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          if (list.length > limit) return list.sublist(0, limit);
          return list;
        });
  }

  /// Create a notification addressed to [userUid]. Silently no-ops if the
  /// recipient is the same as the current signed-in user (we don't want to
  /// notify yourself for your own actions).
  Future<void> create({
    required String userUid,
    required AppNotificationType type,
    required String title,
    required String body,
    Map<String, dynamic>? payload,
    String? skipIfRecipientIs,
  }) async {
    if (userUid.isEmpty) return;
    if (skipIfRecipientIs != null && skipIfRecipientIs == userUid) return;
    try {
      await _db
          .collection(_col)
          .add(
            AppNotification.buildPayload(
              userUid: userUid,
              type: type,
              title: title,
              body: body,
              payload: payload,
            ),
          );
    } catch (e) {
      // Notifications are best-effort. Don't fail the parent transaction.
      debugPrint('[NotificationService] create error: $e');
    }
  }

  Future<void> markRead(String notificationId) async {
    try {
      await _db.collection(_col).doc(notificationId).update({'read': true});
    } catch (e) {
      debugPrint('[NotificationService] markRead error: $e');
    }
  }

  /// Marks the given notification ids as read in a single batch. Caller is
  /// responsible for filtering to only ids that are currently unread — we
  /// avoid running a `userUid + read` Firestore query so no extra composite
  /// index is needed.
  Future<void> markIdsRead(Iterable<String> ids) async {
    final chunk = ids.take(400).toList();
    if (chunk.isEmpty) return;
    try {
      final batch = _db.batch();
      for (final id in chunk) {
        batch.update(_db.collection(_col).doc(id), {'read': true});
      }
      await batch.commit();
    } catch (e) {
      debugPrint('[NotificationService] markIdsRead error: $e');
    }
  }
}
