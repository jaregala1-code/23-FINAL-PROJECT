// lib/providers/pantry_provider.dart

import 'dart:async';
import 'package:flutter/material.dart';

import '../models/surplus_item.dart';
import '../services/pantry_service.dart';

class PantryProvider extends ChangeNotifier {
  final PantryService _svc = PantryService.instance;

  List<SurplusItem> _items = [];
  bool _loading = false;
  String? _error;
  StreamSubscription<List<SurplusItem>>? _sub;

  List<SurplusItem> get items => _items;
  bool get loading => _loading;
  String? get error => _error;

  void startListening() {
    _loading = true;
    notifyListeners();
    _sub = _svc.streamAvailableItems().listen(
      (list) {
        _items = list;
        _loading = false;
        _error = null;
        notifyListeners();
      },
      onError: (e) {
        _error = e.toString();
        _loading = false;
        notifyListeners();
      },
    );
  }

  void stopListening() {
    _sub?.cancel();
    _sub = null;
  }

  @override
  void dispose() {
    stopListening();
    super.dispose();
  }

  Future<String?> postItem(SurplusItem item) => _svc.postItem(item);
  Future<void> updateItem(String id, Map<String, dynamic> f) =>
      _svc.updateItem(id, f);
  Future<void> deleteItem(String id) => _svc.deleteItem(id);

  Future<void> requestItem({
    required String itemId,
    required String requesterUid,
    required String requesterName,
  }) =>
      _svc.requestItem(
        itemId: itemId,
        requesterUid: requesterUid,
        requesterName: requesterName,
      );

  Future<void> acceptRequest({
    required String itemId,
    required String requesterUid,
    required String requesterName,
    DateTime? meetupTime,
  }) =>
      _svc.acceptRequest(
        itemId: itemId,
        requesterUid: requesterUid,
        requesterName: requesterName,
        meetupTime: meetupTime,
      );

  Future<void> markCompleted(String itemId) => _svc.markCompleted(itemId);
}
