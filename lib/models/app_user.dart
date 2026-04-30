class AppUser {
  final String uid;
  final String email;
  final String firstName;
  final String lastName;
  final String displayName;
  final List<String> dietaryTags;
  final bool isVerified;
  final String? photoUrl;
  final double? discoveryRadius;

  const AppUser({
    required this.uid,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.displayName,
    this.dietaryTags = const [],
    this.isVerified = false,
    this.photoUrl,
    this.discoveryRadius = 5.0,
  });

  factory AppUser.fromMap(Map<String, dynamic> map, String uid) {
    return AppUser(
      uid: uid,
      email: map['email'] ?? '',
      firstName: map['firstName'] ?? '',
      lastName: map['lastName'] ?? '',
      displayName: map['displayName'] ?? '',
      dietaryTags: List<String>.from(map['dietaryTags'] ?? []),
      isVerified: map['isVerified'] ?? false,
      photoUrl: map['photoUrl'],
      discoveryRadius: (map['discoveryRadius'] as num?)?.toDouble() ?? 5.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'firstName': firstName,
      'lastName': lastName,
      'displayName': displayName,
      'dietaryTags': dietaryTags,
      'isVerified': isVerified,
      'photoUrl': photoUrl,
      'discoveryRadius': discoveryRadius,
    };
  }

  AppUser copyWith({
    String? firstName,
    String? lastName,
    String? displayName,
    List<String>? dietaryTags,
    bool? isVerified,
    String? photoUrl,
    double? discoveryRadius,
  }) {
    return AppUser(
      uid: uid,
      email: email,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      displayName: displayName ?? this.displayName,
      dietaryTags: dietaryTags ?? this.dietaryTags,
      isVerified: isVerified ?? this.isVerified,
      photoUrl: photoUrl ?? this.photoUrl,
      discoveryRadius: discoveryRadius ?? this.discoveryRadius,
    );
  }
}
