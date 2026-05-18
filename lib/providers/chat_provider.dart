// lib/providers/chat_provider.dart

import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/chat_model.dart';

class ChatProvider extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const String _chats = 'chats';
  static const String _messages = 'messages';

  // ── Streams ──────────────────────────────────────────────────────────────

  Stream<List<Chat>> getChatsStream(String uid) => _db
      .collection(_chats)
      .where('participants', arrayContains: uid)
      .where('isArchived', isEqualTo: false)
      .orderBy('updatedAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(Chat.fromFirestore).toList());

  Stream<List<ChatMessage>> getMessagesStream(String chatId) => _db
      .collection(_chats)
      .doc(chatId)
      .collection(_messages)
      .orderBy('timestamp')
      .snapshots()
      .map((s) => s.docs.map(ChatMessage.fromFirestore).toList());

  // ── Create / get chat ─────────────────────────────────────────────────────

  Future<String> getOrCreateChat({
    required String myUid,
    required String myName,
    required String otherUid,
    required String otherName,
    String? relatedItemId,
    String? relatedItemTitle,
  }) async {
    final chatId = Chat.generateId(myUid, otherUid);
    final ref = _db.collection(_chats).doc(chatId);

    final snap = await ref.get();
    if (!snap.exists) {
      final chat = Chat(
        id: chatId,
        participants: [myUid, otherUid],
        participantNames: {myUid: myName, otherUid: otherName},
        relatedItemId: relatedItemId,
        relatedItemTitle: relatedItemTitle,
        updatedAt: DateTime.now(),
      );
      await ref.set(chat.toFirestore());
    }
    return chatId;
  }

  // ── Send message ──────────────────────────────────────────────────────────

  Future<bool> sendMessage({
    required String chatId,
    required String senderId,
    required String senderName,
    required String text,
    ChatMessageType type = ChatMessageType.text,
    String? qrToken,
    String? qrItemTitle,
  }) async {
    try {
      final msgRef = _db
          .collection(_chats)
          .doc(chatId)
          .collection(_messages)
          .doc();
      final msg = ChatMessage(
        id: msgRef.id,
        senderId: senderId,
        senderName: senderName,
        text: text,
        timestamp: DateTime.now(),
        type: type,
        qrToken: qrToken,
        qrItemTitle: qrItemTitle,
      );
      await msgRef.set(msg.toFirestore());
      // The chat list preview text mirrors the kind of message that was sent.
      final preview = type == ChatMessageType.qr
          ? '📲 Shared QR code'
          : type == ChatMessageType.system
          ? 'ℹ️ $text'
          : text;
      await _db.collection(_chats).doc(chatId).update({
        'lastMessage': preview,
        'lastSenderId': senderId,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('[ChatProvider] sendMessage error: $e');
      return false;
    }
  }

  /// Convenience for posting an inline QR code into the chat.
  Future<bool> sendQrMessage({
    required String chatId,
    required String senderId,
    required String senderName,
    required String qrToken,
    required String itemTitle,
  }) => sendMessage(
    chatId: chatId,
    senderId: senderId,
    senderName: senderName,
    text: 'Pickup QR code',
    type: ChatMessageType.qr,
    qrToken: qrToken,
    qrItemTitle: itemTitle,
  );

  // ── Archive chat (called on item completion) ──────────────────────────────

  Future<void> archiveChat(String chatId) async {
    try {
      await _db.collection(_chats).doc(chatId).update({'isArchived': true});
    } catch (e) {
      debugPrint('[ChatProvider] archiveChat error: $e');
    }
  }
}
