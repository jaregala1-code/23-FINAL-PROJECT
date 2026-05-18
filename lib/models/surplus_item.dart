// lib/models/surplus_item.dart

import 'package:cloud_firestore/cloud_firestore.dart';

// ─── Status lifecycle ─────────────────────────────────────────────────────────
// available → (receiver requests) → reserved → (QR handshake) → completed

enum ItemStatus { available, reserved, completed }

// ─────────────────────────────────────────────────────────────────────────────
// SurplusItem
// ─────────────────────────────────────────────────────────────────────────────

class SurplusItem {
  const SurplusItem({
    this.id,
    required this.title,
    required this.description,
    required this.quantity,
    required this.expirationDate,
    required this.photoBase64,
    required this.ownerUid,
    required this.ownerName,
    this.tags = const [],
    this.status = ItemStatus.available,
    this.claimedByUid,
    this.claimedByName,
    this.meetupTime,
    this.createdAt,
    this.location,
    this.locationAddress,
  });

  final String? id;
  final String title;
  final String description;
  final String quantity; // e.g. "3 eggs", "half a bag of rice"
  final DateTime expirationDate; // spec: timestamped expiration date
  final String photoBase64; // spec: photo taken via camera → base64 string
  final String ownerUid;
  final String ownerName;
  final List<String> tags; // dietary/interest tags, e.g. ['vegan', 'halal']
  final ItemStatus status;
  final String? claimedByUid;
  final String? claimedByName;
  final DateTime? meetupTime;
  final DateTime? createdAt;

  final GeoPoint? location;
  final String? locationAddress;

  // ── Firestore serialization ───────────────────────────────────────────────

  Map<String, dynamic> toFirestore() => {
    'title': title,
    'description': description,
    'quantity': quantity,
    'expirationDate': Timestamp.fromDate(expirationDate),
    'photoBase64': photoBase64,
    'ownerUid': ownerUid,
    'ownerName': ownerName,
    'tags': tags,
    'status': status.name,
    'claimedByUid': claimedByUid,
    'claimedByName': claimedByName,
    'meetupTime': meetupTime != null ? Timestamp.fromDate(meetupTime!) : null,
    'createdAt': FieldValue.serverTimestamp(),
    if (location != null) 'location': location,
    if (locationAddress != null) 'locationAddress': locationAddress,
  };

  factory SurplusItem.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data()! as Map<String, dynamic>;
    return SurplusItem(
      id: doc.id,
      title: d['title'] as String,
      description: d['description'] as String? ?? '',
      quantity: d['quantity'] as String,
      expirationDate: (d['expirationDate'] as Timestamp).toDate(),
      photoBase64: d['photoBase64'] as String,
      ownerUid: d['ownerUid'] as String,
      ownerName: d['ownerName'] as String,
      tags: List<String>.from(d['tags'] ?? []),
      status: ItemStatus.values.firstWhere(
        (e) => e.name == d['status'],
        orElse: () => ItemStatus.available,
      ),
      claimedByUid: d['claimedByUid'] as String?,
      claimedByName: d['claimedByName'] as String?,
      meetupTime: (d['meetupTime'] as Timestamp?)?.toDate(),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
      location: d['location'] as GeoPoint?,
      locationAddress: d['locationAddress'] as String?,
    );
  }

  SurplusItem copyWith({
    String? id,
    String? title,
    String? description,
    String? quantity,
    DateTime? expirationDate,
    String? photoBase64,
    String? ownerUid,
    String? ownerName,
    List<String>? tags,
    ItemStatus? status,
    String? claimedByUid,
    String? claimedByName,
    DateTime? meetupTime,
    DateTime? createdAt,
  }) => SurplusItem(
    id: id ?? this.id,
    title: title ?? this.title,
    description: description ?? this.description,
    quantity: quantity ?? this.quantity,
    expirationDate: expirationDate ?? this.expirationDate,
    photoBase64: photoBase64 ?? this.photoBase64,
    ownerUid: ownerUid ?? this.ownerUid,
    ownerName: ownerName ?? this.ownerName,
    tags: tags ?? this.tags,
    status: status ?? this.status,
    claimedByUid: claimedByUid ?? this.claimedByUid,
    claimedByName: claimedByName ?? this.claimedByName,
    meetupTime: meetupTime ?? this.meetupTime,
    createdAt: createdAt ?? this.createdAt,
    location: location ?? this.location,
    locationAddress: locationAddress ?? this.locationAddress,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// ItemRequest
// Stored in: surplus_items/{itemId}/requests/{requesterUid}
// ─────────────────────────────────────────────────────────────────────────────

class ItemRequest {
  const ItemRequest({
    required this.requesterUid,
    required this.requesterName,
    this.status = 'pending',
    this.requestedAt,
  });

  final String requesterUid;
  final String requesterName;
  final String status; // 'pending' | 'accepted'
  final DateTime? requestedAt;

  factory ItemRequest.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data()! as Map<String, dynamic>;
    return ItemRequest(
      requesterUid: d['requesterUid'] as String,
      requesterName: d['requesterName'] as String,
      status: d['status'] as String? ?? 'pending',
      requestedAt: (d['requestedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'requesterUid': requesterUid,
    'requesterName': requesterName,
    'status': status,
    'requestedAt': FieldValue.serverTimestamp(),
  };
}
