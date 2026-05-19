// lib/services/claim_service.dart
//
// Manages the full ClaimRequest lifecycle:
//   request → giver approves (+ QR token generated) → QR scanned → completed
// Also opens the chat thread on approval and fires in-app notifications at
// every important transition.

import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/app_notification.dart';
import '../models/chat_model.dart';
import 'notification_service.dart';

class ClaimService {
  ClaimService._();
  static final ClaimService instance = ClaimService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const String _col = 'surplus_items';
  static const String _claims = 'claimRequests'; // top-level collection
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

      await NotificationService.instance.create(
        userUid: ownerUid,
        skipIfRecipientIs: requesterUid,
        type: AppNotificationType.claimRequested,
        title: 'New request for "$itemTitle"',
        body: '$requesterName wants to claim this item.',
        payload: {'itemId': itemId, 'requesterUid': requesterUid},
      );

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

      final pendingClaimsSnap = await _db
          .collection(_claims)
          .where('ownerUid', isEqualTo: ownerUid)
          .where('itemId', isEqualTo: itemId)
          .get();

      final rejectionTargets = <_RejectionTarget>[];

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

      for (final doc in pendingClaimsSnap.docs) {
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
          batch.update(
            _db
                .collection(_col)
                .doc(itemId)
                .collection('requests')
                .doc(data['requesterUid'] as String),
            {'status': 'rejected'},
          );
          rejectionTargets.add(
            _RejectionTarget(
              uid: data['requesterUid'] as String? ?? '',
              name: data['requesterName'] as String? ?? 'You',
            ),
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
          'lastMessage': null,
          'lastSenderId': null,
          'updatedAt': FieldValue.serverTimestamp(),
          'relatedItemId': itemId,
          'relatedItemTitle': itemTitle,
          'isArchived': false,
        });
      }

      await batch.commit();

      await NotificationService.instance.create(
        userUid: requesterUid,
        skipIfRecipientIs: ownerUid,
        type: AppNotificationType.claimApproved,
        title: 'Approved: "$itemTitle"',
        body: 'Open your Tray to show the pickup QR code to $ownerName.',
        payload: {'itemId': itemId, 'chatId': chatId},
      );

      for (final target in rejectionTargets) {
        if (target.uid.isEmpty) continue;
        await NotificationService.instance.create(
          userUid: target.uid,
          skipIfRecipientIs: ownerUid,
          type: AppNotificationType.claimRejected,
          title: '"$itemTitle" is no longer available',
          body: 'The giver picked another requester.',
          payload: {'itemId': itemId},
        );
      }

      return true;
    } catch (e) {
      debugPrint('[ClaimService] approveRequester error: $e');
      return false;
    }
  }

  // ── Complete exchange via QR (Giver scans) ────────────────────────────────

  Future<bool> completeExchange({
    required String itemId,
    required String itemTitle,
    required String reqId,
    required String claimerId,
    required String ownerUid,
  }) async {
    try {
      final approvedClaimsSnap = await _db
          .collection(_claims)
          .where('ownerUid', isEqualTo: ownerUid)
          .where('itemId', isEqualTo: itemId)
          .get();

      DocumentReference? targetClaim;
      for (final doc in approvedClaimsSnap.docs) {
        final data = doc.data();
        if (data['requesterUid'] != claimerId) continue;
        if (data['status'] != 'approved') continue;
        targetClaim = doc.reference;
        break;
      }

      if (targetClaim == null) {
        debugPrint(
          '[ClaimService] completeExchange: no approved claim found for '
          'item=$itemId claimer=$claimerId',
        );
        return false;
      }

      final batch = _db.batch();

      batch.update(_db.collection(_col).doc(itemId), {
        'status': 'completed',
        'completedAt': FieldValue.serverTimestamp(),
      });

      batch.update(targetClaim, {
        'status': 'completed',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      batch.update(
        _db.collection(_col).doc(itemId).collection('requests').doc(claimerId),
        {'status': 'completed'},
      );

      await batch.commit();

      await NotificationService.instance.create(
        userUid: claimerId,
        skipIfRecipientIs: ownerUid,
        type: AppNotificationType.claimCompleted,
        title: 'Pickup complete 🎉',
        body: 'Thanks for picking up "$itemTitle".',
        payload: {'itemId': itemId},
      );

      return true;
    } catch (e) {
      debugPrint('[ClaimService] completeExchange error: $e');
      return false;
    }
  }

  // ── Set agreed pickup time (Giver schedules from chat) ───────────────────

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

      batch.update(
        _db
            .collection(_col)
            .doc(itemId)
            .collection('requests')
            .doc(requesterUid),
        {'agreedPickupTime': ts},
      );

      final chatId = Chat.generateId(ownerUid, requesterUid);
      batch.update(_db.collection(_chats).doc(chatId), {
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      await NotificationService.instance.create(
        userUid: requesterUid,
        skipIfRecipientIs: ownerUid,
        type: AppNotificationType.pickupScheduled,
        title: 'Pickup scheduled for "$itemTitle"',
        body: '$otherPartyName set the time. Tap to view the chat.',
        payload: {
          'itemId': itemId,
          'chatId': chatId,
          'meetupTimeMs': meetupTime.millisecondsSinceEpoch,
        },
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
      final claimSnap = await _db.collection(_claims).doc(claimDocId).get();
      final claimData = claimSnap.data();

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

      if (claimData != null) {
        final ownerUid = claimData['ownerUid'] as String? ?? '';
        final requesterName =
            claimData['requesterName'] as String? ?? 'A receiver';
        final itemTitle = claimData['itemTitle'] as String? ?? 'your item';
        if (ownerUid.isNotEmpty) {
          await NotificationService.instance.create(
            userUid: ownerUid,
            skipIfRecipientIs: requesterUid,
            type: AppNotificationType.claimCancelled,
            title: 'Request cancelled',
            body: '$requesterName withdrew their request for "$itemTitle".',
            payload: {'itemId': itemId},
          );
        }
      }
      return true;
    } catch (e) {
      debugPrint('[ClaimService] cancelClaim error: $e');
      return false;
    }
  }
}

class _RejectionTarget {
  final String uid;
  final String name;
  const _RejectionTarget({required this.uid, required this.name});
}
