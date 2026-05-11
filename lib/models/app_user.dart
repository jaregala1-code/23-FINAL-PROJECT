// lib/models/app_user.dart

import 'package:cloud_firestore/cloud_firestore.dart';

// ─── Verification lifecycle ───────────────────────────────────────────────────
enum VerificationStatus { unverified, pending, verified, rejected }

// ─────────────────────────────────────────────────────────────────────────────
// DietaryTag — used by both the signup flow and location preference widget
// ─────────────────────────────────────────────────────────────────────────────

class DietaryTag {
  const DietaryTag({
    required this.id,
    required this.label,
    required this.emoji,
  });
  final String id;
  final String label;
  final String emoji;
}

// Unified tag catalogue — superset of both codebases
const List<DietaryTag> kFoodTags = [
  DietaryTag(id: 'vegan', label: 'Vegan', emoji: '🌱'),
  DietaryTag(id: 'vegetarian', label: 'Vegetarian', emoji: '🥦'),
  DietaryTag(id: 'halal', label: 'Halal', emoji: '☪️'),
  DietaryTag(id: 'gluten_free', label: 'Gluten-Free', emoji: '🌾'),
  DietaryTag(id: 'dairy_free', label: 'Dairy-Free', emoji: '🥛'),
  DietaryTag(id: 'home_cooked', label: 'Home-Cooked', emoji: '🍳'),
  DietaryTag(id: 'raw_ingredients', label: 'Raw Ingredients', emoji: '🥕'),
  DietaryTag(id: 'rice_meals', label: 'Rice Meals', emoji: '🍚'),
  DietaryTag(id: 'seafood', label: 'Seafood', emoji: '🦐'),
  DietaryTag(id: 'bbq_grilled', label: 'BBQ / Grilled', emoji: '🔥'),
  DietaryTag(id: 'street_food', label: 'Street Food', emoji: '🍢'),
  DietaryTag(id: 'desserts', label: 'Desserts', emoji: '🍮'),
  DietaryTag(id: 'coffee_drinks', label: 'Coffee & Drinks', emoji: '☕'),
  DietaryTag(id: 'keto', label: 'Keto', emoji: '🥑'),
  DietaryTag(id: 'fruit', label: 'Fresh Fruits', emoji: '🍎'),
  DietaryTag(id: 'bakery', label: 'Bakery & Bread', emoji: '🥖'),
  DietaryTag(id: 'pantry', label: 'Pantry Staples', emoji: '🫙'),
  DietaryTag(id: 'organic', label: 'Organic', emoji: '♻️'),
];

// ─────────────────────────────────────────────────────────────────────────────
// AppUser
// ─────────────────────────────────────────────────────────────────────────────

class AppUser {
  const AppUser({
    required this.uid,
    required this.email,
    this.firstName = '',
    this.lastName = '',
    this.displayName = '',
    // Tags — stored as string IDs; both 'dietaryTags' and 'foodTagIds' map here
    this.foodTagIds = const [],
    // Verification
    this.verificationStatus = VerificationStatus.unverified,
    this.verificationSelfieBase64,
    this.verificationSubmittedAt,
    // Profile photo (base64, no Firebase Storage needed)
    this.profileImageBase64,
    // Legacy photoUrl field kept for any existing Firestore docs
    this.photoUrl,
    // Location
    this.location,
    this.locationAddress,
    this.radiusKm = 2.0,
  });

  final String uid;
  final String email;
  final String firstName;
  final String lastName;
  final String displayName;

  // Tags
  final List<String> foodTagIds;
  // Alias getter so milestone widgets that reference dietaryTags still work
  List<String> get dietaryTags => foodTagIds;

  // Verification
  final VerificationStatus verificationStatus;
  final String? verificationSelfieBase64;
  final DateTime? verificationSubmittedAt;
  bool get isVerified => verificationStatus == VerificationStatus.verified;

  // Photos
  final String? profileImageBase64;
  final String? photoUrl; // legacy URL field

  // Location
  final GeoPoint? location;
  final String? locationAddress;
  final double radiusKm;
  // Alias so old code referencing discoveryRadius compiles
  double get discoveryRadius => radiusKm;

  // ── Firestore serialization ───────────────────────────────────────────────

  Map<String, dynamic> toFirestore() => {
    'email': email,
    'firstName': firstName,
    'lastName': lastName,
    'displayName': displayName,
    'foodTagIds': foodTagIds,
    'dietaryTags': foodTagIds, // write both keys for compat
    'verificationStatus': verificationStatus.name,
    'verificationSelfieBase64': verificationSelfieBase64,
    'verificationSubmittedAt': verificationSubmittedAt != null
        ? Timestamp.fromDate(verificationSubmittedAt!)
        : null,
    'profileImageBase64': profileImageBase64,
    'photoUrl': photoUrl,
    'location': location,
    'locationAddress': locationAddress,
    'radiusKm': radiusKm,
  };

  // Alias so old ELBites code calling toMap() still works
  Map<String, dynamic> toMap() => toFirestore();

  factory AppUser.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data()! as Map<String, dynamic>;
    return AppUser._fromMap(doc.id, d);
  }

  // fromMap constructor so old FirestoreUserAPI code still works
  factory AppUser.fromMap(Map<String, dynamic> d, String uid) =>
      AppUser._fromMap(uid, d);

  factory AppUser._fromMap(String uid, Map<String, dynamic> d) {
    // Accept tags stored under either key
    final rawTags =
        (d['foodTagIds'] as List?)?.cast<String>() ??
        (d['dietaryTags'] as List?)?.cast<String>() ??
        <String>[];
    return AppUser(
      uid: uid,
      email: d['email'] as String? ?? '',
      firstName: d['firstName'] as String? ?? '',
      lastName: d['lastName'] as String? ?? '',
      displayName: d['displayName'] as String? ?? '',
      foodTagIds: rawTags,
      verificationStatus: VerificationStatus.values.firstWhere(
        (e) => e.name == d['verificationStatus'],
        orElse: () => VerificationStatus.unverified,
      ),
      verificationSelfieBase64: d['verificationSelfieBase64'] as String?,
      verificationSubmittedAt: (d['verificationSubmittedAt'] as Timestamp?)
          ?.toDate(),
      profileImageBase64: d['profileImageBase64'] as String?,
      photoUrl: d['photoUrl'] as String?,
      location: d['location'] as GeoPoint?,
      locationAddress: d['locationAddress'] as String?,
      radiusKm:
          (d['radiusKm'] as num?)?.toDouble() ??
          (d['discoveryRadius'] as num?)?.toDouble() ??
          2.0,
    );
  }

  AppUser copyWith({
    String? email,
    String? firstName,
    String? lastName,
    String? displayName,
    List<String>? foodTagIds,
    VerificationStatus? verificationStatus,
    String? verificationSelfieBase64,
    DateTime? verificationSubmittedAt,
    String? profileImageBase64,
    String? photoUrl,
    GeoPoint? location,
    String? locationAddress,
    double? radiusKm,
  }) => AppUser(
    uid: uid,
    email: email ?? this.email,
    firstName: firstName ?? this.firstName,
    lastName: lastName ?? this.lastName,
    displayName: displayName ?? this.displayName,
    foodTagIds: foodTagIds ?? this.foodTagIds,
    verificationStatus: verificationStatus ?? this.verificationStatus,
    verificationSelfieBase64:
        verificationSelfieBase64 ?? this.verificationSelfieBase64,
    verificationSubmittedAt:
        verificationSubmittedAt ?? this.verificationSubmittedAt,
    profileImageBase64: profileImageBase64 ?? this.profileImageBase64,
    photoUrl: photoUrl ?? this.photoUrl,
    location: location ?? this.location,
    locationAddress: locationAddress ?? this.locationAddress,
    radiusKm: radiusKm ?? this.radiusKm,
  );
}
