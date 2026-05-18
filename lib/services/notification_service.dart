// lib/services/notification_service.dart
//
// One service that handles:
//   - FCM permission + token storage (used by the Cloud Function to push)
//   - Foreground FCM messages → local notification (so the user actually sees it)
//   - Scheduled local pickup reminders 1 hour before agreed meetup time
//   - Local fallback "new matching item" alert when the pantry stream emits

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/surplus_item.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const _channelNewItem = AndroidNotificationChannel(
    'elbites_new_items',
    'New food nearby',
    description: 'Alerts when a new item matching your dietary tags is posted',
    importance: Importance.high,
  );
  static const _channelPickup = AndroidNotificationChannel(
    'elbites_pickup',
    'Pickup reminders',
    description: 'Reminds you 1 hour before an agreed meetup',
    importance: Importance.high,
  );
  static const _channelChat = AndroidNotificationChannel(
    'elbites_chat',
    'Chat messages',
    description: 'New chat messages',
    importance: Importance.high,
  );

  bool _initialized = false;

  // ── Init ─────────────────────────────────────────────────────────────────

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    // Timezone for scheduled notifications
    tz_data.initializeTimeZones();
    try {
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
    } catch (e) {
      debugPrint('[NotificationService] tz init failed: $e');
    }

    // Local notifications init
    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    await _local.initialize(initSettings);

    // Create Android channels up front
    final androidImpl = _local
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidImpl?.createNotificationChannel(_channelNewItem);
    await androidImpl?.createNotificationChannel(_channelPickup);
    await androidImpl?.createNotificationChannel(_channelChat);
    await androidImpl?.requestNotificationsPermission();

    // FCM permission
    await _fcm.requestPermission(alert: true, badge: true, sound: true);

    // Foreground messages → show as local notification
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Token refresh → write to user doc
    _fcm.onTokenRefresh.listen((token) {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) _saveFcmToken(uid, token);
    });
  }

  // ── FCM token (stored per-user so the Cloud Function can target them) ────

  Future<void> registerFcmToken(String uid) async {
    try {
      final token = await _fcm.getToken();
      if (token != null) await _saveFcmToken(uid, token);
    } catch (e) {
      debugPrint('[NotificationService] registerFcmToken: $e');
    }
  }

  Future<void> _saveFcmToken(String uid, String token) async {
    await _db.collection('users').doc(uid).set({
      'fcmTokens': FieldValue.arrayUnion([token]),
      'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> unregisterFcmToken(String uid) async {
    try {
      final token = await _fcm.getToken();
      if (token == null) return;
      await _db.collection('users').doc(uid).set({
        'fcmTokens': FieldValue.arrayRemove([token]),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[NotificationService] unregisterFcmToken: $e');
    }
  }

  // ── Foreground FCM handler ───────────────────────────────────────────────

  Future<void> _handleForegroundMessage(RemoteMessage msg) async {
    final notification = msg.notification;
    if (notification == null) return;
    final channelId = _resolveChannelId(msg.data['type'] as String?);
    await _local.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelId == _channelChat.id
              ? _channelChat.name
              : channelId == _channelPickup.id
              ? _channelPickup.name
              : _channelNewItem.name,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: msg.data.isEmpty ? null : jsonEncode(msg.data),
    );
  }

  String _resolveChannelId(String? type) {
    switch (type) {
      case 'pickup_reminder':
        return _channelPickup.id;
      case 'chat':
        return _channelChat.id;
      default:
        return _channelNewItem.id;
    }
  }

  // ── Pickup reminder (scheduled local notification) ───────────────────────

  Future<void> schedulePickupReminder({
    required String tag,
    required DateTime meetupTime,
    required String itemTitle,
    required String otherPartyName,
  }) async {
    final fireAt = meetupTime.subtract(const Duration(hours: 1));
    if (fireAt.isBefore(DateTime.now())) return;

    await _local.zonedSchedule(
      _stableHash(tag),
      'Pickup reminder',
      '$itemTitle with $otherPartyName in 1 hour',
      tz.TZDateTime.from(fireAt, tz.local),
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelPickup.id,
          _channelPickup.name,
          channelDescription: _channelPickup.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      // v18 still requires this even though it's a no-op on Android.
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: jsonEncode({'type': 'pickup_reminder', 'tag': tag}),
    );
  }

  Future<void> cancelPickupReminder(String tag) =>
      _local.cancel(_stableHash(tag));

  // ── Local fallback: alert on new matching item ───────────────────────────

  Future<void> maybeNotifyNewItem({
    required SurplusItem item,
    required dynamic me, // AppUser?, kept dynamic to avoid model import cycle
  }) async {
    if (me == null) return;
    if (item.ownerUid == me.uid) return;
    if (me.notifyNewItems != true) return;

    // Dietary tag overlap
    final userTags =
        (me.foodTagIds as List?)?.cast<String>() ?? const <String>[];
    if (userTags.isNotEmpty && item.tags.isNotEmpty) {
      final userTagsLower = userTags.map((t) => t.toLowerCase()).toSet();
      final itemTagsLower = item.tags.map((t) => t.toLowerCase()).toSet();
      final hasOverlap = userTagsLower.intersection(itemTagsLower).isNotEmpty;
      if (!hasOverlap) return;
    }

    // Distance gate — only enforced when BOTH sides have coords.
    final userGeo = me.location as GeoPoint?;
    if (userGeo != null && item.location != null) {
      final radiusKm = (me.radiusKm as num?)?.toDouble() ?? 2.0;
      final km = _haversineKm(
        userGeo.latitude,
        userGeo.longitude,
        item.location!.latitude,
        item.location!.longitude,
      );
      if (radiusKm > 0 && km > radiusKm) return;
    }

    await _local.show(
      _stableHash('newitem-${item.id ?? item.title}'),
      '🍱 New ${item.title} nearby',
      item.description.isNotEmpty
          ? item.description
          : 'Posted by ${item.ownerName}',
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelNewItem.id,
          _channelNewItem.name,
          channelDescription: _channelNewItem.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: jsonEncode({'type': 'new_item', 'itemId': item.id}),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  /// Great-circle distance in kilometres between two lat/lng pairs.
  double _haversineKm(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371.0; // Earth radius in km
    final dLat = (lat2 - lat1) * (3.141592653589793 / 180);
    final dLng = (lng2 - lng1) * (3.141592653589793 / 180);
    final a =
        (math.sin(dLat / 2) * math.sin(dLat / 2)) +
        math.cos(lat1 * (3.141592653589793 / 180)) *
            math.cos(lat2 * (3.141592653589793 / 180)) *
            (math.sin(dLng / 2) * math.sin(dLng / 2));
    return 2 * r * math.asin(math.sqrt(a));
  }

  int _stableHash(String s) {
    // 31-bit stable hash so it fits in an Android notification id (int).
    var h = 0;
    for (final c in s.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return h;
  }
}
