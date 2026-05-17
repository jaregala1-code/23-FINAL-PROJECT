// lib/services/pantry_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../models/surplus_item.dart';
import 'image_service.dart';

class PantryService {
  PantryService._();
  static final PantryService instance = PantryService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const String _col = 'surplus_items';

  // ── Photo capture ─────────────────────────────────────────────────────────

  /// Opens the rear camera and returns a base64 string.
  /// Spec: "Must include a photo taken via the camera" — gallery is blocked.
  Future<String?> captureItemPhoto() => ImageService.instance.pickAndEncode(
    source: ImageSource.camera,
    camera: CameraDevice.rear,
    quality: 75,
    maxWidth: 900,
  );

  /// Decodes a stored base64 photo string for display with [Image.memory].
  Uint8List decodePhoto(String base64) => ImageService.instance.decode(base64);

  // ── CREATE ────────────────────────────────────────────────────────────────

  Future<String?> postItem(SurplusItem item) async {
    try {
      // Generate the doc ref locally so we can return its id immediately.
      // We don't await the server commit — Firestore's offline cache fires
      // snapshot listeners right away, so the UI sees the new item without
      // waiting for the network roundtrip (which made the "Post" spinner
      // hang long after the item was already in the feed).
      final ref = _db.collection(_col).doc();
      ref.set(item.toFirestore()).catchError((e) {
        debugPrint('[PantryService] postItem write error: $e');
      });
      return ref.id;
    } catch (e) {
      debugPrint('[PantryService] postItem error: $e');
      return null;
    }
  }

  // ── READ ──────────────────────────────────────────────────────────────────

  /// All available items, newest first — drives the main Pantry feed.
  Stream<List<SurplusItem>> streamAvailableItems() => _db
      .collection(_col)
      .where('status', isEqualTo: ItemStatus.available.name)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(SurplusItem.fromFirestore).toList());

  /// Items posted by a specific user — used in "My Posts".
  Stream<List<SurplusItem>> streamMyItems(String uid) => _db
      .collection(_col)
      .where('ownerUid', isEqualTo: uid)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(SurplusItem.fromFirestore).toList());

  /// Items claimed/reserved by a specific user — used in "My Claims".
  Stream<List<SurplusItem>> streamMyClaimedItems(String uid) => _db
      .collection(_col)
      .where('claimedByUid', isEqualTo: uid)
      .snapshots()
      .map((s) => s.docs.map(SurplusItem.fromFirestore).toList());

  /// Incoming requests on an item — used on the owner's detail view.
  Stream<List<ItemRequest>> streamRequests(String itemId) => _db
      .collection(_col)
      .doc(itemId)
      .collection('requests')
      .snapshots()
      .map((s) => s.docs.map(ItemRequest.fromFirestore).toList());

  // ── UPDATE ────────────────────────────────────────────────────────────────

  Future<void> updateItem(String id, Map<String, dynamic> fields) async {
    try {
      await _db.collection(_col).doc(id).update(fields);
    } catch (e) {
      debugPrint('[PantryService] updateItem error: $e');
      rethrow;
    }
  }

  // ── DELETE ────────────────────────────────────────────────────────────────

  Future<void> deleteItem(String id) async {
    try {
      await _db.collection(_col).doc(id).delete();
    } catch (e) {
      debugPrint('[PantryService] deleteItem error: $e');
      rethrow;
    }
  }

  // ── CLAIMING SYSTEM ───────────────────────────────────────────────────────

  /// Receiver sends a claim request — writes to the requests sub-collection.
  Future<void> requestItem({
    required String itemId,
    required String requesterUid,
    required String requesterName,
  }) => _db
      .collection(_col)
      .doc(itemId)
      .collection('requests')
      .doc(requesterUid)
      .set(
        ItemRequest(
          requesterUid: requesterUid,
          requesterName: requesterName,
        ).toFirestore(),
      );

  /// Owner accepts a request — atomically marks item Reserved + request Accepted.
  Future<void> acceptRequest({
    required String itemId,
    required String requesterUid,
    required String requesterName,
    DateTime? meetupTime,
  }) async {
    final batch = _db.batch();
    batch.update(_db.collection(_col).doc(itemId), {
      'status': ItemStatus.reserved.name,
      'claimedByUid': requesterUid,
      'claimedByName': requesterName,
      'meetupTime': meetupTime != null ? Timestamp.fromDate(meetupTime) : null,
    });
    batch.update(
      _db.collection(_col).doc(itemId).collection('requests').doc(requesterUid),
      {'status': 'accepted'},
    );
    await batch.commit();
  }

  /// Called by the QR Handshake screen (Milestone 3) after a successful scan.
  Future<void> markCompleted(String itemId) => _db
      .collection(_col)
      .doc(itemId)
      .update({'status': ItemStatus.completed.name});
}
