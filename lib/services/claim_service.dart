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
  static const String _claims = 'claimRequests';
  static const String _chats = 'chats';

  // ── Streams ───────────────────────────────────────────────────────────────

  Stream<List<Map<String, dynamic>>> streamRequesters(String itemId) => _db
      .collection(_col)
      .doc(itemId)
      .collection('requests')
      .snapshots()
      .map((s) => s.docs.map((d) => {'id': d.id, ...d.data()}).toList());

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
      final reqId = const Uuid().v4();
      final qrToken = jsonEncode({
        'reqId': reqId,
        'claimerId': requesterUid,
        'itemId': itemId,
      });

      final batch = _db.batch();

      batch.update(_db.collection(_col).doc(itemId), {
        'status': 'reserved',
        'claimedByUid': requesterUid,
        'claimedByName': requesterName,
        'qrToken': qrToken,
        'qrReqId': reqId,
      });

      batch.update(
        _db
            .collection(_col)
            .doc(itemId)
            .collection('requests')
            .doc(requesterUid),
        {'status': 'accepted'},
      );

      // Find pending claims for this item. The ownerUid filter is required
      // by Firestore security rules: list queries must encode a predicate
      // matching the read rule (ownerUid == auth.uid here).
      final pendingClaims = await _db
          .collection(_claims)
          .where('itemId', isEqualTo: itemId)
          .where('ownerUid', isEqualTo: ownerUid)
          .where('status', isEqualTo: 'pending')
          .get();

      for (final doc in pendingClaims.docs) {
        final data = doc.data();
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
          'lastMessage': '📲 Shared QR code',
          'lastSenderId': ownerUid,
          'updatedAt': FieldValue.serverTimestamp(),
          'relatedItemId': itemId,
          'relatedItemTitle': itemTitle,
          'isArchived': false,
        });
      } else {
        batch.update(chatRef, {
          'lastMessage': '📲 Shared QR code',
          'lastSenderId': ownerUid,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      final qrMsgRef = chatRef.collection('messages').doc();
      batch.set(qrMsgRef, {
        'senderId': ownerUid,
        'senderName': ownerName,
        'text': 'Show this QR at pickup for $itemTitle',
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'type': 'qr',
        'qrToken': qrToken,
        'qrItemTitle': itemTitle,
      });

      await batch.commit();
      return true;
    } catch (e) {
      debugPrint('[ClaimService] approveRequester error: $e');
      return false;
    }
  }

  // ── Complete exchange via QR (Giver scans) ────────────────────────────────

  /// [ownerUid] is the signed-in giver who's scanning. We verify the item
  /// actually belongs to them before flipping status — otherwise anyone with
  /// a leaked QR token could mark the exchange complete.
  Future<bool> completeExchange({
    required String itemId,
    required String reqId,
    required String claimerId,
    String? ownerUid,
  }) async {
    try {
      // Fall back to the signed-in user if no ownerUid was passed — Firestore
      // rules need it on the claimRequests list query below.
      ownerUid ??= FirebaseAuth.instance.currentUser?.uid;
      if (ownerUid == null) return false;

      // Ownership guard
      final itemSnap = await _db.collection(_col).doc(itemId).get();
      final data = itemSnap.data();
      if (data == null) return false;
      if (data['ownerUid'] != ownerUid) {
        debugPrint('[ClaimService] completeExchange: caller is not owner');
        return false;
      }
      final storedToken = data['qrReqId'] as String?;
      if (storedToken != null && storedToken != reqId) {
        debugPrint('[ClaimService] completeExchange: reqId mismatch');
        return false;
      }

      final batch = _db.batch();

      batch.update(_db.collection(_col).doc(itemId), {
        'status': 'completed',
        'completedAt': FieldValue.serverTimestamp(),
        'completedByUid': ownerUid,
      });

      // Mark approved claim as completed. The ownerUid filter satisfies
      // Firestore's list-query rule requirement (see notes above).
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

  // ── Agree on meetup time ──────────────────────────────────────────────────

  Future<bool> setAgreedPickupTime({
    required String itemId,
    required String itemTitle,
    required String requesterUid,
    required String otherPartyName,
    required DateTime meetupTime,
  }) async {
    try {
      final batch = _db.batch();
      final ts = Timestamp.fromDate(meetupTime);

      // Mirror onto the item doc — only the giver can do this (rule enforced).
      batch.update(_db.collection(_col).doc(itemId), {
        'meetupTime': ts,
        'pickupReminderScheduledAt': Timestamp.fromDate(
          meetupTime.subtract(const Duration(hours: 1)),
        ),
      });

      batch.update(
        _db
            .collection(_col)
            .doc(itemId)
            .collection('requests')
            .doc(requesterUid),
        {'agreedPickupTime': ts},
      );

      // Top-level claim docs for this item+requester.
      // The ownerUid clause is mandatory: Firestore security rules require
      // the query itself to encode the "I'm a party to this doc" predicate,
      // and only the giver calls this method (button is gated to them in
      // chat_screen.dart). Without this clause the query fails with
      // permission-denied even though every returned doc would satisfy the
      // rule.
      final myUid = FirebaseAuth.instance.currentUser?.uid;
      final claims = await _db
          .collection(_claims)
          .where('itemId', isEqualTo: itemId)
          .where('ownerUid', isEqualTo: myUid)
          .where('requesterUid', isEqualTo: requesterUid)
          .get();
      for (final d in claims.docs) {
        batch.update(d.reference, {
          'agreedPickupTime': ts,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
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
}
