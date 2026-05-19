// lib/models/app_notification.dart
//

import 'package:cloud_firestore/cloud_firestore.dart';

enum AppNotificationType {
  claimRequested, //  giver: someone requested your item
  claimApproved, // receiver: your claim was approved
  claimRejected, //  receiver: your claim was rejected
  claimCancelled, //  giver: receiver cancelled
  claimCompleted, //  receiver: exchange completed
  pickupScheduled, // receiver: giver set a pickup time
  message, //  recipient: new chat message
}

String _typeToWire(AppNotificationType t) {
  switch (t) {
    case AppNotificationType.claimRequested:
      return 'claim_requested';
    case AppNotificationType.claimApproved:
      return 'claim_approved';
    case AppNotificationType.claimRejected:
      return 'claim_rejected';
    case AppNotificationType.claimCancelled:
      return 'claim_cancelled';
    case AppNotificationType.claimCompleted:
      return 'claim_completed';
    case AppNotificationType.pickupScheduled:
      return 'pickup_scheduled';
    case AppNotificationType.message:
      return 'message';
  }
}

AppNotificationType _typeFromWire(String? raw) {
  switch (raw) {
    case 'claim_requested':
      return AppNotificationType.claimRequested;
    case 'claim_approved':
      return AppNotificationType.claimApproved;
    case 'claim_rejected':
      return AppNotificationType.claimRejected;
    case 'claim_cancelled':
      return AppNotificationType.claimCancelled;
    case 'claim_completed':
      return AppNotificationType.claimCompleted;
    case 'pickup_scheduled':
      return AppNotificationType.pickupScheduled;
    case 'message':
      return AppNotificationType.message;
    default:
      return AppNotificationType.message;
  }
}

class AppNotification {
  final String id;
  final String userUid;
  final AppNotificationType type;
  final String title;
  final String body;
  final bool read;
  final DateTime createdAt;
  final Map<String, dynamic> payload;

  const AppNotification({
    required this.id,
    required this.userUid,
    required this.type,
    required this.title,
    required this.body,
    required this.read,
    required this.createdAt,
    this.payload = const {},
  });

  factory AppNotification.fromFirestore(DocumentSnapshot doc) {
    final d = (doc.data() as Map<String, dynamic>?) ?? const {};
    return AppNotification(
      id: doc.id,
      userUid: d['userUid'] as String? ?? '',
      type: _typeFromWire(d['type'] as String?),
      title: d['title'] as String? ?? '',
      body: d['body'] as String? ?? '',
      read: d['read'] as bool? ?? false,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      payload: (d['payload'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
  }

  static Map<String, dynamic> buildPayload({
    required String userUid,
    required AppNotificationType type,
    required String title,
    required String body,
    Map<String, dynamic>? payload,
  }) => {
    'userUid': userUid,
    'type': _typeToWire(type),
    'title': title,
    'body': body,
    'read': false,
    'createdAt': FieldValue.serverTimestamp(),
    if (payload != null && payload.isNotEmpty) 'payload': payload,
  };
}
