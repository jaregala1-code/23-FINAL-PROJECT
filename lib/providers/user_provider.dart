// lib/providers/user_provider.dart
//
// Thin wrapper used by milestone widgets (ProfilePhotoWidget,
// LocationPreferenceWidget, VerificationSelfieScreen, AddItemScreen).
// Delegates Firestore reads/writes to FirestoreUserAPI so there is
// a single source of truth for user data.

import 'package:flutter/material.dart';
import '../api/firestore_user_api.dart';
import '../models/app_user.dart';

class UserProvider extends ChangeNotifier {
  final FirestoreUserAPI _db = FirestoreUserAPI();

  AppUser? _user;
  bool _loading = false;

  AppUser? get user => _user;
  bool get loading => _loading;

  // ── Seed from auth provider (call after login) ───────────────────────────
  void seedUser(AppUser user) {
    _user = user;
    notifyListeners();
  }

  // ── Load from Firestore ───────────────────────────────────────────────────
  Future<void> loadUser(String uid) async {
    _loading = true;
    notifyListeners();
    try {
      _user = await _db.getUser(uid) ?? AppUser(uid: uid, email: '');
    } catch (_) {
      _user ??= AppUser(uid: uid, email: '');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  // ── Merge fields & refresh ────────────────────────────────────────────────
  Future<void> updateUser(Map<String, dynamic> fields) async {
    if (_user == null) return;
    await _db.updateUser(_user!.uid, fields);
    await loadUser(_user!.uid);
  }

  // ── Clear on logout ───────────────────────────────────────────────────────
  void clear() {
    _user = null;
    notifyListeners();
  }
}
