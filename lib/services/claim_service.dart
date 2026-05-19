// lib/services/claim_service.dart
//
// Manages the full ClaimRequest lifecycle:
//   request → giver approves (+ QR token generated) → QR scanned → completed
// Also opens the chat thread on approval.

import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

      // 1. Reserve the item
      batch.update(_db.collection(_col).doc(itemId), {
        'status': 'reserved',
        'claimedByUid': requesterUid,
        'claimedByName': requesterName,
        'qrToken': qrToken,
        'qrReqId': reqId,
      });

      // 2. Approve the selected requester in sub-collection
      batch.update(
        _db
            .collection(_col)
            .doc(itemId)
            .collection('requests')
            .doc(requesterUid),
        {'status': 'accepted'},
      );

      // 3. Update top-level claimRequest docs — approve selected, reject others
      // Find pending claims for this item. We constrain by `ownerUid` so the
      // Firestore security rules on `claimRequests` accept the collection
      // query: the per-doc rule requires `ownerUid == auth.uid` and Firestore
      // refuses queries that aren't statically constrained to match it.
      // `status` is filtered client-side below to avoid needing an extra
      // composite index.
      final pendingClaims = await _db
          .collection(_claims)
          .where('ownerUid', isEqualTo: ownerUid)
          .where('itemId', isEqualTo: itemId)
          .get();

      for (final doc in pendingClaims.docs) {
        final data = doc.data();
        if (data['status'] != 'pending') continue;
        final isSelected = data['requesterUid'] == requesterUid;
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
          // Reject in sub-collection too
          batch.update(
            _db
                .collection(_col)
                .doc(itemId)
                .collection('requests')
                .doc(data['requesterUid']),
            {'status': 'rejected'},
          );
        }
      }

      // 4. Create chat between Giver and approved Receiver
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
    required String ownerUid,
  }) async {
    try {
      final batch = _db.batch();

      // Mark item completed
      batch.update(_db.collection(_col).doc(itemId), {
        'status': 'completed',
        'completedAt': FieldValue.serverTimestamp(),
      });

      // Mark approved claim as completed. As with approveRequester, we must
      // constrain by `ownerUid` for the Firestore rule to allow the query;
      // `requesterUid` + `status` are filtered client-side.
      final approvedClaims = await _db
          .collection(_claims)
          .where('ownerUid', isEqualTo: ownerUid)
          .where('itemId', isEqualTo: itemId)
          .get();

      for (final doc in approvedClaims.docs) {
        final data = doc.data();
        if (data['requesterUid'] != claimerId) continue;
        if (data['status'] != 'approved') continue;
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

  // ── Set agreed pickup time (Giver schedules from chat) ───────────────────
  //
  // Updates `agreedPickupTime` on:
  //   - claimRequests/{docId}  (top-level, the source of truth used by Tray)
  //   - surplus_items/{itemId}/requests/{requesterUid}  (sub-collection mirror)
  //
  // The caller must be the item's giver (Firestore rules enforce this on the
  // surplus_items doc). We read the giver's uid from FirebaseAuth so the
  // signature stays simple for chat_screen.dart.

  Future<bool> setAgreedPickupTime({
    required String itemId,
    required String itemTitle,
    required String requesterUid,
    required String otherPartyName,
    required DateTime meetupTime,
  }) async {
    try {
      final ownerUid = FirebaseAuth.instance.currentUser?.uid;
      if (ownerUid == null) {
        debugPrint('[ClaimService] setAgreedPickupTime: not signed in');
        return false;
      }

      // Find the active claim doc by (ownerUid, itemId), then filter to the
      // specific requester client-side. Filtering by ownerUid is required
      // for the Firestore rules to accept the collection query.
      final snap = await _db
          .collection(_claims)
          .where('ownerUid', isEqualTo: ownerUid)
          .where('itemId', isEqualTo: itemId)
          .get();

      DocumentReference? targetClaim;
      for (final doc in snap.docs) {
        final data = doc.data();
        if (data['requesterUid'] != requesterUid) continue;
        final status = data['status'] as String?;
        // Allow scheduling on approved (post-accept) and pending (rare —
        // pickup time agreed before formal QR approval).
        if (status == 'approved' || status == 'pending') {
          targetClaim = doc.reference;
          break;
        }
      }

      if (targetClaim == null) {
        debugPrint(
          '[ClaimService] setAgreedPickupTime: no active claim for '
          'item=$itemId requester=$requesterUid',
        );
        return false;
      }

      final batch = _db.batch();
      final ts = Timestamp.fromDate(meetupTime);

      batch.update(targetClaim, {
        'agreedPickupTime': ts,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Sub-collection mirror; keyed by requesterUid so we don't need a query.
      batch.update(
        _db
            .collection(_col)
            .doc(itemId)
            .collection('requests')
            .doc(requesterUid),
        {'agreedPickupTime': ts},
      );

      // Touch the chat doc so the chat list reflects the activity. The chat
      // id is deterministic from the two uids.
      final chatId = Chat.generateId(ownerUid, requesterUid);
      batch.update(_db.collection(_chats).doc(chatId), {
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
      // Use the params so analyzer doesn't flag them; they double as a
      // future hook for sending a structured notification.
      debugPrint(
        '[ClaimService] pickup set for "$itemTitle" with $otherPartyName '
        'at $meetupTime',
      );
      return true;
    } catch (e) {
      debugPrint('[ClaimService] setAgreedPickupTime error: $e');
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
