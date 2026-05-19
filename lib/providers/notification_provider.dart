// lib/providers/notification_provider.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/app_notification.dart';
import '../services/notification_service.dart';

class NotificationProvider extends ChangeNotifier {
  final NotificationService _svc = NotificationService.instance;

  String? _uid;
  StreamSubscription<List<AppNotification>>? _sub;
  List<AppNotification> _items = const [];

  List<AppNotification> get items => _items;
  int get unreadCount => _items.where((n) => !n.read).length;
  bool get hasUnread => unreadCount > 0;

  /// Bind the provider to a user. Pass null on sign-out.
  void bindUser(String? uid) {
    if (uid == _uid) return;
    _uid = uid;
    _sub?.cancel();
    _sub = null;

    if (uid == null || uid.isEmpty) {
      _items = const [];
      notifyListeners();
      return;
    }

    _sub = _svc
        .streamForUser(uid)
        .listen(
          (list) {
            _items = list;
            notifyListeners();
          },
          onError: (e) {
            debugPrint('[NotificationProvider] stream error: $e');
          },
        );
  }

  Future<void> markRead(String notificationId) async {
    final idx = _items.indexWhere((n) => n.id == notificationId);
    if (idx != -1 && !_items[idx].read) {
      final updated = AppNotification(
        id: _items[idx].id,
        userUid: _items[idx].userUid,
        type: _items[idx].type,
        title: _items[idx].title,
        body: _items[idx].body,
        read: true,
        createdAt: _items[idx].createdAt,
        payload: _items[idx].payload,
      );
      _items = [..._items]..[idx] = updated;
      notifyListeners();
    }
    await _svc.markRead(notificationId);
  }

  Future<void> markAllRead() async {
    if (_uid == null) return;
    final unreadIds = _items.where((n) => !n.read).map((n) => n.id).toList();
    if (unreadIds.isEmpty) return;
    _items = _items
        .map(
          (n) => n.read
              ? n
              : AppNotification(
                  id: n.id,
                  userUid: n.userUid,
                  type: n.type,
                  title: n.title,
                  body: n.body,
                  read: true,
                  createdAt: n.createdAt,
                  payload: n.payload,
                ),
        )
        .toList();
    notifyListeners();
    await _svc.markIdsRead(unreadIds);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _sub = null;
    super.dispose();
  }
}
