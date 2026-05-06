import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_user.dart';

class FirestoreUserAPI {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const String _collection = 'users';

  Future<void> createUser(AppUser user) async {
    await _db.collection(_collection).doc(user.uid).set(user.toMap());
  }

  Future<AppUser?> getUser(String uid) async {
    final doc = await _db.collection(_collection).doc(uid).get();
    if (!doc.exists || doc.data() == null) return null;
    return AppUser.fromMap(doc.data()!, uid);
  }

  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    await _db.collection(_collection).doc(uid).update(data);
  }

  Stream<AppUser?> userStream(String uid) {
    return _db.collection(_collection).doc(uid).snapshots().map((snap) {
      if (!snap.exists || snap.data() == null) return null;
      return AppUser.fromMap(snap.data()!, uid);
    });
  }
}
