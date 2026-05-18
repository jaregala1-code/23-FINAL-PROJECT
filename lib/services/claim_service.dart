// lib/services/claim_service.dart
//
// Manages the full ClaimRequest lifecycle:
//   request → giver approves (+ QR token generated) → QR scanned → completed
// Also opens the chat thread on approval.

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
  static const String _claims = 'claimRequests'; // top-level collection
  static const String _chats = 'chats';

  // ── Streams ───────────────────────────────────────────────────────────────

  /// All pending requests on a specific item (Giver's Requesters Page)
  Stream<List<Map<String, dynamic>>> streamRequesters(String itemId) => _db
      .collection(_col)
      .doc(itemId)
      .collection('requests')
      .snapshots()
      .map((s) => s.docs.map((d) => {'id': d.id, ...d.data()}).toList());

  /// All claim requests for the current receiver (Tray)
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

      // Write to surplus_items/{itemId}/requests/{requesterUid}
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
          'requestedAt': FieldValue.serverTimestamp(),
        },
      );

      // Also write to top-level claimRequests for easy querying by receiver
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
      // Generate QR token
      final reqId = const Uuid().v4();
      final qrToken = jsonEncode({
        'reqId': reqId,
        'claimerId': requesterUid,
        'itemId': itemId,
      });

      final batch = _db.batch();
      // Track sub-collection request docs we've already queued in this batch
      final touchedRequestDocs = <String>{};

      // 1. Reserve the item
      batch.update(_db.collection(_col).doc(itemId), {
        'status': 'reserved',
        'claimedByUid': requesterUid,
        'claimedByName': requesterName,
        'qrToken': qrToken,
        'qrReqId': reqId,
      });

      // 2. Approve the selected requester in sub-collection.
      batch.set(
        _db
            .collection(_col)
            .doc(itemId)
            .collection('requests')
            .doc(requesterUid),
        {'status': 'accepted'},
        SetOptions(merge: true),
      );
      touchedRequestDocs.add(requesterUid);

      // 3. Update top-level claimRequest docs — approve selected, reject others
      final pendingClaims = await _db
          .collection(_claims)
          .where('itemId', isEqualTo: itemId)
          .where('ownerUid', isEqualTo: ownerUid)
          .where('status', isEqualTo: 'pending')
          .get();

      for (final doc in pendingClaims.docs) {
        final data = doc.data();
        final otherUid = data['requesterUid'] as String?;
        final isSelected = otherUid == requesterUid;
        if (isSelected) {
          batch.update(doc.reference, {
            'status': 'approved',
            'qrToken': qrToken,
            'reqId': reqId,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else {
          batch.update(doc.reference, {
            'status': 'rejected',
            'updatedAt': FieldValue.serverTimestamp(),
          });
          // Reject in sub-collection too — guarded against null/empty uid
          // (legacy claim docs) and against double-writing the same doc.
          if (otherUid != null &&
              otherUid.isNotEmpty &&
              !touchedRequestDocs.contains(otherUid)) {
            batch.set(
              _db
                  .collection(_col)
                  .doc(itemId)
                  .collection('requests')
                  .doc(otherUid),
              {'status': 'rejected'},
              SetOptions(merge: true),
            );
            touchedRequestDocs.add(otherUid);
          }
        }
      }

      // 4. Create chat between Giver and approved Receiver
      final chatId = Chat.generateId(ownerUid, requesterUid);
      batch.set(_db.collection(_chats).doc(chatId), {
        'participants': [ownerUid, requesterUid],
        'participantNames': {ownerUid: ownerName, requesterUid: requesterName},
        'updatedAt': FieldValue.serverTimestamp(),
        'relatedItemId': itemId,
        'relatedItemTitle': itemTitle,
        'isArchived': false,
      }, SetOptions(merge: true));

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
    required String ownerUid,
  }) async {
    try {
      final batch = _db.batch();

      // Mark item completed
      batch.update(_db.collection(_col).doc(itemId), {
        'status': 'completed',
        'completedAt': FieldValue.serverTimestamp(),
      });

      // Mark approved claim as completed
      final approvedClaims = await _db
          .collection(_claims)
          .where('itemId', isEqualTo: itemId)
          .where('ownerUid', isEqualTo: ownerUid)
          .where('requesterUid', isEqualTo: claimerId)
          .where('status', isEqualTo: 'approved')
          .get();

      for (final doc in approvedClaims.docs) {
        batch.update(doc.reference, {
          'status': 'completed',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

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
      // Remove from sub-collection
      batch.delete(
        _db
            .collection(_col)
            .doc(itemId)
            .collection('requests')
            .doc(requesterUid),
      );
      // Update top-level claim
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
}
