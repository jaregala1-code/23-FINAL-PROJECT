// lib/providers/location_provider.dart
//
// Manages GPS detection state and persists location + radius to Firestore.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/location_service.dart';

class LocationProvider extends ChangeNotifier {
  double? _latitude;
  double? _longitude;
  String _address = 'No location set';
  double _radiusKm = 2.0;

  bool _detecting = false;
  String? _error;

  double? get latitude => _latitude;
  double? get longitude => _longitude;
  String get address => _address;
  double get radiusKm => _radiusKm;
  bool get detecting => _detecting;
  String? get error => _error;
  bool get hasLocation => _latitude != null && _longitude != null;

  Future<void> loadFromFirestore(String uid) async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    if (!doc.exists) return;
    final d = doc.data()!;
    final geo = d['location'] as GeoPoint?;
    _latitude = geo?.latitude;
    _longitude = geo?.longitude;
    _address = d['locationAddress'] as String? ?? 'No location set';
    _radiusKm = (d['radiusKm'] as num?)?.toDouble() ?? 2.0;
    notifyListeners();
  }

  Future<void> detectLocation() async {
    _detecting = true;
    _error = null;
    notifyListeners();
    try {
      final result = await LocationService.instance.detectLocation();
      _latitude = result.latitude;
      _longitude = result.longitude;
      _address = result.address;
    } catch (e) {
      _error = e.toString();
    } finally {
      _detecting = false;
      notifyListeners();
    }
  }

  void setRadius(double km) {
    _radiusKm = km;
    notifyListeners();
  }

  Future<void> saveToFirestore(String uid) async {
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'location': hasLocation ? GeoPoint(_latitude!, _longitude!) : null,
      'locationAddress': _address,
      'radiusKm': _radiusKm,
      'preferencesUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
