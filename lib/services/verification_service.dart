// lib/services/verification_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../models/app_user.dart';
import 'image_service.dart';

class VerificationService {
  VerificationService._();
  static final VerificationService instance = VerificationService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Captures a front-camera selfie and submits it to Firestore.
  /// Returns true on success, false if user cancelled.
  Future<bool> captureAndSubmit(String uid) async {
    try {
      // Camera only — not gallery. Front camera = selfie.
      final String? base64 = await ImageService.instance.pickAndEncode(
        source: ImageSource.camera,
        camera: CameraDevice.front,
        quality: 80,
        maxWidth: 800,
      );
      if (base64 == null) return false;

      await _db.collection('users').doc(uid).set({
        'verificationSelfieBase64': base64,
        'verificationStatus': VerificationStatus.pending.name,
        'verificationSubmittedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      return true;
    } catch (e) {
      debugPrint('[VerificationService] captureAndSubmit error: $e');
      return false;
    }
  }

  /// Live stream of the user's verification status.
  /// Used to update the badge in real-time without a manual refresh.
  Stream<VerificationStatus> watchStatus(String uid) {
    return _db.collection('users').doc(uid).snapshots().map((snap) {
      final raw = snap.data()?['verificationStatus'] as String?;
      return VerificationStatus.values.firstWhere(
        (e) => e.name == raw,
        orElse: () => VerificationStatus.unverified,
      );
    });
  }
}
