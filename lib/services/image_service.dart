// lib/services/image_service.dart

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

class ImageService {
  ImageService._();
  static final ImageService instance = ImageService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final ImagePicker _picker = ImagePicker();

  // ── Pick & encode ─────────────────────────────────────────────────────────

  /// Opens camera or gallery, compresses, and returns a base64 string.
  /// Returns null if the user cancels.
  Future<String?> pickAndEncode({
    ImageSource source = ImageSource.gallery,
    CameraDevice camera = CameraDevice.rear,
    int quality = 75,
    double maxWidth = 800,
  }) async {
    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        preferredCameraDevice: camera,
        imageQuality: quality,
        maxWidth: maxWidth,
      );
      if (file == null) return null;
      return _fileToBase64(file.path);
    } catch (e) {
      debugPrint('[ImageService] pickAndEncode error: $e');
      return null;
    }
  }

  /// Encodes an existing [File] to base64.
  Future<String> encodeFile(File file) => _fileToBase64(file.path);

  // ── Decode ────────────────────────────────────────────────────────────────

  /// Decodes a base64 string to raw bytes for use with [Image.memory].
  /// Strips a data-URL prefix (e.g. "data:image/png;base64,…") if present.
  Uint8List decode(String base64String) {
    final clean = base64String.contains(',')
        ? base64String.split(',').last
        : base64String;
    return base64Decode(clean);
  }

  // ── Firestore write ───────────────────────────────────────────────────────

  /// Stores a base64 string as a field inside a Firestore document.
  /// Uses merge:true so other fields in the document are not overwritten.
  ///
  /// [collection]  — Firestore collection name, e.g. 'users'
  /// [documentId]  — existing doc ID to update, or null to auto-create
  /// [fieldName]   — the key under which the base64 string is stored
  /// [extraFields] — any additional fields to merge in the same write
  ///
  /// Returns the document ID on success, null on failure.
  Future<String?> storeToFirestore({
    required String base64String,
    required String collection,
    String? documentId,
    String fieldName = 'imageBase64',
    Map<String, dynamic> extraFields = const {},
  }) async {
    try {
      final payload = <String, dynamic>{
        fieldName: base64String,
        '${fieldName}_updatedAt': FieldValue.serverTimestamp(),
        ...extraFields,
      };

      if (documentId != null) {
        await _db
            .collection(collection)
            .doc(documentId)
            .set(payload, SetOptions(merge: true));
        return documentId;
      } else {
        final ref = await _db.collection(collection).add(payload);
        return ref.id;
      }
    } catch (e) {
      debugPrint('[ImageService] storeToFirestore error: $e');
      return null;
    }
  }

  // ── Firestore read ────────────────────────────────────────────────────────

  /// Fetches a base64 image field from Firestore and decodes it.
  /// Returns null if the document or field is missing.
  Future<Uint8List?> fetchFromFirestore({
    required String collection,
    required String documentId,
    String fieldName = 'imageBase64',
  }) async {
    try {
      final doc = await _db.collection(collection).doc(documentId).get();
      if (!doc.exists) return null;

      final raw = (doc.data() as Map<String, dynamic>?)?[fieldName] as String?;
      if (raw == null || raw.isEmpty) return null;

      return decode(raw);
    } catch (e) {
      debugPrint('[ImageService] fetchFromFirestore error: $e');
      return null;
    }
  }

  /// Stream variant — re-emits bytes whenever the Firestore document changes.
  Stream<Uint8List?> watchFromFirestore({
    required String collection,
    required String documentId,
    String fieldName = 'imageBase64',
  }) {
    return _db.collection(collection).doc(documentId).snapshots().map((snap) {
      if (!snap.exists) return null;
      final raw = (snap.data() as Map<String, dynamic>?)?[fieldName] as String?;
      if (raw == null || raw.isEmpty) return null;
      return decode(raw);
    });
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  Future<String> _fileToBase64(String path) async {
    final bytes = await File(path).readAsBytes();
    return base64Encode(bytes);
  }
}
