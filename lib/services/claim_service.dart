// lib/services/claim_service.dart

import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/chat_model.dart';

class ClaimService {
  ClaimService._();
  static final ClaimService instance = ClaimService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const String _col = 'surplus_items';
  static const String _claims = 'claimRequests';
  static const String _chats = 'chats';

  // ── Streams ───────────────────────────────────────────────────────────────

  /// Requesters on a specific item — only pending ones.
  Stream<List<Map<String, dynamic>>> streamRequesters(String itemId) => _db
      .collection(_col)
      .doc(itemId)
      .collection('requests')
      .where('status', isEqualTo: 'pending')
      .snapshots()
      .map((s) => s.docs.map((d) => {'id': d.id, ...d.data()}).toList());

  /// All active claim requests for the current receiver (Tray).
  Stream<List<Map<String, dynamic>>> streamMyClaims(String uid) => _db
      .collection(_claims)
      .where('requesterUid', isEqualTo: uid)
      .where('status', whereIn: ['pending', 'approved'])
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map((d) => {'docId': d.id, ...d.data()}).toList());

  // ── Create claim request ──────────────────────────────────────────────────

  Future<bool> requestItem({
    required String itemId,
    required String itemTitle,
    required String ownerUid,
    required String ownerName,
    required String requesterUid,
    required String requesterName,
    String? requesterPhotoBase64,
  }) async {
    try {
      final reqId = const Uuid().v4();
      final batch = _db.batch();

      // Sub-collection doc keyed by requesterUid — stores reqId for later
      batch.set(
        _db
            .collection(_col)
            .doc(itemId)
            .collection('requests')
            .doc(requesterUid),
        {
          'requesterUid': requesterUid,
          'requesterName': requesterName,
          'requesterPhotoBase64': requesterPhotoBase64,
          'status': 'pending',
          'reqId': reqId,
          'requestedAt': FieldValue.serverTimestamp(),
        },
      );

      // Top-level claimRequests doc — doc ID is the reqId itself
      batch.set(_db.collection(_claims).doc(reqId), {
        'reqId': reqId,
        'itemId': itemId,
        'itemTitle': itemTitle,
        'ownerUid': ownerUid,
        'ownerName': ownerName,
        'requesterUid': requesterUid,
        'requesterName': requesterName,
        'requesterPhotoBase64': requesterPhotoBase64,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
      return true;
    } catch (e) {
      debugPrint('[ClaimService] requestItem error: $e');
      return false;
    }
  }

  // ── Approve requester (Giver) ─────────────────────────────────────────────

  Future<bool> approveRequester({
    required String itemId,
    required String itemTitle,
    required String ownerUid,
    required String ownerName,
    required String requesterUid,
    required String requesterName,
  }) async {
    try {
      // 1. Read sub-collection doc to get the reqId written at swipe time
      final subDoc = await _db
          .collection(_col)
          .doc(itemId)
          .collection('requests')
          .doc(requesterUid)
          .get();

      final existingReqId = subDoc.data()?['reqId'] as String?;
      final reqId = existingReqId ?? const Uuid().v4();

      final qrToken = jsonEncode({
        'reqId': reqId,
        'claimerId': requesterUid,
        'itemId': itemId,
      });

      final batch = _db.batch();

      // 2. Reserve the surplus item
      batch.update(_db.collection(_col).doc(itemId), {
        'status': 'reserved',
        'claimedByUid': requesterUid,
        'claimedByName': requesterName,
        'qrToken': qrToken,
        'qrReqId': reqId,
      });

      // 3. Mark selected requester as accepted in sub-collection
      batch.update(
        _db
            .collection(_col)
            .doc(itemId)
            .collection('requests')
            .doc(requesterUid),
        {'status': 'accepted'},
      );

      // 4. Update top-level claimRequests doc directly by reqId — no query needed
      batch.update(_db.collection(_claims).doc(reqId), {
        'status': 'approved',
        'qrToken': qrToken,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 5. Reject all OTHER pending requesters for this item.
      //    FIX: filter by ownerUid so the Firestore rule (caller == owner) is satisfied.
      final otherPending = await _db
          .collection(_claims)
          .where('itemId', isEqualTo: itemId)
          .where('ownerUid', isEqualTo: ownerUid)
          .where('status', isEqualTo: 'pending')
          .get();

      for (final doc in otherPending.docs) {
        final data = doc.data();
        if (data['requesterUid'] == requesterUid)
          continue; // skip the approved one
        final otherRequesterUid = data['requesterUid'] as String?;

        // Reject top-level doc
        batch.update(doc.reference, {
          'status': 'rejected',
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Reject sub-collection doc
        if (otherRequesterUid != null) {
          batch.update(
            _db
                .collection(_col)
                .doc(itemId)
                .collection('requests')
                .doc(otherRequesterUid),
            {'status': 'rejected'},
          );
        }
      }

      // 6. Create chat thread between Giver and approved Receiver
      final chatId = Chat.generateId(ownerUid, requesterUid);
      final chatRef = _db.collection(_chats).doc(chatId);
      final chatSnap = await chatRef.get();
      if (!chatSnap.exists) {
        batch.set(chatRef, {
          'participants': [ownerUid, requesterUid],
          'participantNames': {
            ownerUid: ownerName,
            requesterUid: requesterName,
          },
          'lastMessage': null,
          'lastSenderId': null,
          'updatedAt': FieldValue.serverTimestamp(),
          'relatedItemId': itemId,
          'relatedItemTitle': itemTitle,
          'isArchived': false,
        });
      }

      await batch.commit();
      return true;
    } catch (e) {
      debugPrint('[ClaimService] approveRequester error: $e');
      return false;
    }
  }

  // ── Complete exchange via QR (Giver scans) ────────────────────────────────

  Future<bool> completeExchange({
    required String itemId,
    required String reqId,
    required String claimerId,
  }) async {
    try {
      final batch = _db.batch();

      // Mark item completed
      batch.update(_db.collection(_col).doc(itemId), {
        'status': 'completed',
        'completedAt': FieldValue.serverTimestamp(),
      });

      // Update top-level claim directly by reqId
      batch.update(_db.collection(_claims).doc(reqId), {
        'status': 'completed',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update sub-collection doc
      batch.update(
        _db.collection(_col).doc(itemId).collection('requests').doc(claimerId),
        {'status': 'completed'},
      );

      await batch.commit();
      return true;
    } catch (e) {
      debugPrint('[ClaimService] completeExchange error: $e');
      return false;
    }
  }

  // ── Remove from tray (Receiver cancels) ──────────────────────────────────

  Future<bool> cancelClaim({
    required String itemId,
    required String requesterUid,
    required String claimDocId,
  }) async {
    try {
      final batch = _db.batch();

      batch.delete(
        _db
            .collection(_col)
            .doc(itemId)
            .collection('requests')
            .doc(requesterUid),
      );

      batch.update(_db.collection(_claims).doc(claimDocId), {
        'status': 'cancelled',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
      return true;
    } catch (e) {
      debugPrint('[ClaimService] cancelClaim error: $e');
      return false;
    }
  }

  // ── Set agreed pickup time ────────────────────────────────────────────────

  Future<bool> setAgreedPickupTime({
    required String itemId,
    required String itemTitle,
    required String requesterUid,
    required String otherPartyName,
    required DateTime meetupTime,
  }) async {
    try {
      final snap = await _db
          .collection(_claims)
          .where('itemId', isEqualTo: itemId)
          .where('requesterUid', isEqualTo: requesterUid)
          .where('status', isEqualTo: 'approved')
          .limit(1)
          .get();

      if (snap.docs.isEmpty) {
        debugPrint(
          '[ClaimService] setAgreedPickupTime: no approved claim found',
        );
        return false;
      }

      await snap.docs.first.reference.update({
        'agreedPickupTime': Timestamp.fromDate(meetupTime),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      debugPrint('[ClaimService] setAgreedPickupTime error: $e');
      return false;
    }
  }
}
