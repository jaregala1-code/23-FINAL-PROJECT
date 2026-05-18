// lib/services/location_service.dart

import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

// ─── Result type returned from detectLocation() ───────────────────────────────

class LocationResult {
  const LocationResult({
    required this.latitude,
    required this.longitude,
    required this.address,
  });

  final double latitude;
  final double longitude;
  final String address; // reverse-geocoded human-readable string
}

// ─────────────────────────────────────────────────────────────────────────────
// LocationService
// ─────────────────────────────────────────────────────────────────────────────

class LocationService {
  LocationService._();
  static final LocationService instance = LocationService._();

  /// Requests permission (if needed) and returns the device's current position
  /// with a reverse-geocoded address string.
  ///
  /// Throws a [String] error message on permission denial or GPS failure —
  /// catch it in the caller (LocationProvider) to surface to the UI.
  Future<LocationResult> detectLocation() async {
    // 1. Check & request permission
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      throw 'Location permission is permanently denied. '
          'Please enable it in device Settings.';
    }
    if (permission == LocationPermission.denied) {
      throw 'Location permission was denied.';
    }

    // 2. Get current GPS position
    final Position pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );

    // 3. Reverse geocode — best-effort; fall back to raw coords
    final String address = await _reverseGeocode(pos.latitude, pos.longitude);

    return LocationResult(
      latitude: pos.latitude,
      longitude: pos.longitude,
      address: address,
    );
  }

  /// Returns metres between two coordinates.
  /// Use this to filter pantry items within the user's radius.
  double distanceInMetres(
    double fromLat,
    double fromLng,
    double toLat,
    double toLng,
  ) => Geolocator.distanceBetween(fromLat, fromLng, toLat, toLng);

  // ── Private ───────────────────────────────────────────────────────────────

  Future<String> _reverseGeocode(double lat, double lng) async {
    try {
      final marks = await placemarkFromCoordinates(lat, lng);
      if (marks.isEmpty) return _rawCoords(lat, lng);
      final p = marks.first;
      final parts = [
        p.street,
        p.subLocality,
        p.locality,
        p.administrativeArea,
      ].where((s) => s != null && s.isNotEmpty).toList();
      return parts.isNotEmpty ? parts.join(', ') : _rawCoords(lat, lng);
    } catch (e) {
      debugPrint('[LocationService] reverseGeocode error: $e');
      return _rawCoords(lat, lng);
    }
  }

  String _rawCoords(double lat, double lng) =>
      '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';
}
