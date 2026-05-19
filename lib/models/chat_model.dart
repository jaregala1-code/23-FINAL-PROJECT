// lib/models/chat_model.dart
//
// Chat and ClaimRequest models for Milestone 2/3 features.

import 'package:cloud_firestore/cloud_firestore.dart';

// ─── ClaimRequest ─────────────────────────────────────────────────────────────
// Stored at: surplus_items/{itemId}/requests/{requesterUid}
// The existing ItemRequest in surplus_item.dart only has basic fields.
// This extended version adds the QR token and claim lifecycle for Milestone 3.

class ClaimRequest {
  final String id;
  final String itemId;
  final String itemTitle;
  final String ownerUid;
  final String ownerName;
  final String requesterUid;
  final String requesterName;
  final String? requesterPhotoBase64;
  final String status; // pending | approved | rejected | completed
  final String? qrToken; // JSON: {reqId, claimerId, itemId}
  final DateTime? agreedPickupTime;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ClaimRequest({
    required this.id,
    required this.itemId,
    required this.itemTitle,
    required this.ownerUid,
    required this.ownerName,
    required this.requesterUid,
    required this.requesterName,
    this.requesterPhotoBase64,
    this.status = 'pending',
    this.qrToken,
    this.agreedPickupTime,
    this.createdAt,
    this.updatedAt,
  });

  factory ClaimRequest.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data()! as Map<String, dynamic>;
    return ClaimRequest(
      id: doc.id,
      itemId: d['itemId'] as String? ?? '',
      itemTitle: d['itemTitle'] as String? ?? '',
      ownerUid: d['ownerUid'] as String? ?? '',
      ownerName: d['ownerName'] as String? ?? '',
      requesterUid: d['requesterUid'] as String? ?? '',
      requesterName: d['requesterName'] as String? ?? '',
      requesterPhotoBase64: d['requesterPhotoBase64'] as String?,
      status: d['status'] as String? ?? 'pending',
      qrToken: d['qrToken'] as String?,
      agreedPickupTime: (d['agreedPickupTime'] as Timestamp?)?.toDate(),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'itemId': itemId,
    'itemTitle': itemTitle,
    'ownerUid': ownerUid,
    'ownerName': ownerName,
    'requesterUid': requesterUid,
    'requesterName': requesterName,
    'requesterPhotoBase64': requesterPhotoBase64,
    'status': status,
    'qrToken': qrToken,
    'agreedPickupTime': agreedPickupTime != null
        ? Timestamp.fromDate(agreedPickupTime!)
        : null,
    'createdAt': createdAt != null
        ? Timestamp.fromDate(createdAt!)
        : FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
  };

  ClaimRequest copyWith({
    String? status,
    String? qrToken,
    DateTime? agreedPickupTime,
  }) => ClaimRequest(
    id: id,
    itemId: itemId,
    itemTitle: itemTitle,
    ownerUid: ownerUid,
    ownerName: ownerName,
    requesterUid: requesterUid,
    requesterName: requesterName,
    requesterPhotoBase64: requesterPhotoBase64,
    status: status ?? this.status,
    qrToken: qrToken ?? this.qrToken,
    agreedPickupTime: agreedPickupTime ?? this.agreedPickupTime,
    createdAt: createdAt,
  );
}

// ─── Chat ─────────────────────────────────────────────────────────────────────
// Chat ID = alphabetically sorted UID pair joined by underscore.
// Stored at: chats/{chatId}
// Messages at: chats/{chatId}/messages/{msgId}

class Chat {
  final String id;
  final List<String> participants;
  final Map<String, String> participantNames;
  final String? lastMessage;
  final String? lastSenderId;
  final DateTime? updatedAt;
  final String? relatedItemId;
  final String? relatedItemTitle;
  final bool isArchived;

  const Chat({
    required this.id,
    required this.participants,
    required this.participantNames,
    this.lastMessage,
    this.lastSenderId,
    this.updatedAt,
    this.relatedItemId,
    this.relatedItemTitle,
    this.isArchived = false,
  });

  factory Chat.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data()! as Map<String, dynamic>;
    return Chat(
      id: doc.id,
      participants: List<String>.from(d['participants'] ?? []),
      participantNames: Map<String, String>.from(d['participantNames'] ?? {}),
      lastMessage: d['lastMessage'] as String?,
      lastSenderId: d['lastSenderId'] as String?,
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate(),
      relatedItemId: d['relatedItemId'] as String?,
      relatedItemTitle: d['relatedItemTitle'] as String?,
      isArchived: d['isArchived'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'participants': participants,
    'participantNames': participantNames,
    'lastMessage': lastMessage,
    'lastSenderId': lastSenderId,
    'updatedAt': FieldValue.serverTimestamp(),
    'relatedItemId': relatedItemId,
    'relatedItemTitle': relatedItemTitle,
    'isArchived': isArchived,
  };

  String getOtherUid(String myUid) =>
      participants.firstWhere((p) => p != myUid, orElse: () => '');

  String getOtherName(String myUid) {
    final other = getOtherUid(myUid);
    return participantNames[other] ?? 'Unknown';
  }

  static String generateId(String uid1, String uid2) {
    final sorted = [uid1, uid2]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }
}

// ─── ChatMessage ─────────────────────────────────────────────────────────────

/// Wire type stored at `chats/{chatId}/messages/{msgId}.type`. Older docs
/// have no `type` field and are treated as plain text.
enum ChatMessageType { text, qr, system }

ChatMessageType _msgTypeFromString(String? raw) {
  switch (raw) {
    case 'qr':
      return ChatMessageType.qr;
    case 'system':
      return ChatMessageType.system;
    case 'text':
    default:
      return ChatMessageType.text;
  }
}

String msgTypeToWireString(ChatMessageType t) {
  switch (t) {
    case ChatMessageType.qr:
      return 'qr';
    case ChatMessageType.system:
      return 'system';
    case ChatMessageType.text:
      return 'text';
  }
}

class ChatMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String text;
  final DateTime timestamp;
  final bool isRead;
  final ChatMessageType type;
  final String? qrToken;
  final String? qrItemTitle;

  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.timestamp,
    this.isRead = false,
    this.type = ChatMessageType.text,
    this.qrToken,
    this.qrItemTitle,
  });

  factory ChatMessage.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data()! as Map<String, dynamic>;
    return ChatMessage(
      id: doc.id,
      senderId: d['senderId'] as String? ?? '',
      senderName: d['senderName'] as String? ?? '',
      text: d['text'] as String? ?? '',
      timestamp: (d['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isRead: d['isRead'] as bool? ?? false,
      type: _msgTypeFromString(d['type'] as String?),
      qrToken: d['qrToken'] as String?,
      qrItemTitle: d['qrItemTitle'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'senderId': senderId,
    'senderName': senderName,
    'text': text,
    'timestamp': Timestamp.fromDate(timestamp),
    'isRead': isRead,
    'type': msgTypeToWireString(type),
    if (qrToken != null) 'qrToken': qrToken,
    if (qrItemTitle != null) 'qrItemTitle': qrItemTitle,
  };
}
