// lib/api/firestore_user_api.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/app_user.dart';

class FirestoreUserAPI {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const String _collection = 'users';

  Future<void> createUser(AppUser user) async {
    // Fire-and-forget the server commit
    _db
        .collection(_collection)
        .doc(user.uid)
        .set(user.toFirestore())
        .catchError((e) {
          debugPrint('[FirestoreUserAPI] createUser write error: $e');
        });
  }

  Future<AppUser?> getUser(String uid) async {
    final doc = await _db.collection(_collection).doc(uid).get();
    if (!doc.exists || doc.data() == null) return null;
    return AppUser.fromFirestore(doc);
  }

  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    await _db
        .collection(_collection)
        .doc(uid)
        .set(data, SetOptions(merge: true));
  }

  Stream<AppUser?> userStream(String uid) {
    return _db.collection(_collection).doc(uid).snapshots().map((snap) {
      if (!snap.exists || snap.data() == null) return null;
      return AppUser.fromFirestore(snap);
    });
  }
}
