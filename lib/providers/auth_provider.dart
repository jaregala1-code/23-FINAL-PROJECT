import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../api/firebase_auth_api.dart';
import '../api/firestore_user_api.dart';
import '../models/app_user.dart';
import '../services/notification_service.dart';

class UserAuthProvider with ChangeNotifier {
  late FirebaseAuthAPI _authService;
  late FirestoreUserAPI _firestoreService;
  late Stream<User?> _uStream;
  String? _errorMessage;
  AppUser? _appUser;
  bool _isLoading = false;

  // Optional callback  set by whoever needs to react after login
  // e.g. to load LocationProvider. Avoids circular provider dependencies.
  void Function(String uid)? onUserLoaded;

  UserAuthProvider() {
    _authService = FirebaseAuthAPI();
    _firestoreService = FirestoreUserAPI();
    _fetchAuthentication();
  }

  Stream<User?> get userStream => _uStream;
  String? get error => _errorMessage;
  AppUser? get appUser => _appUser;
  bool get isLoading => _isLoading;

  void _fetchAuthentication() {
    _uStream = _authService.getUser();
    notifyListeners();
  }

  Future<void> loadAppUser(String uid) async {
    _appUser = await _firestoreService.getUser(uid);
    notifyListeners();
    onUserLoaded?.call(uid);
  }

  Future<bool> signUp({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String displayName,
    required List<String> dietaryTags,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    _errorMessage = await _authService.signUp(
      email,
      password,
      displayName: displayName,
    );

    if (_errorMessage != null) {
      _isLoading = false;
      notifyListeners();
      return false;
    }

    final uid = _authService.currentUser?.uid;
    if (uid == null) {
      _errorMessage = 'Unexpected error. Please try again.';
      _isLoading = false;
      notifyListeners();
      return false;
    }

    final newUser = AppUser(
      uid: uid,
      email: email,
      firstName: firstName,
      lastName: lastName,
      displayName: displayName,
      foodTagIds: dietaryTags,
    );

    try {
      await _firestoreService.createUser(newUser);
      _appUser = newUser;
      onUserLoaded?.call(uid);
    } catch (e) {
      _errorMessage = 'Failed to save profile. Please try again.';
      _isLoading = false;
      notifyListeners();
      return false;
    }

    _isLoading = false;
    notifyListeners();
    return true;
  }

  Future<void> signIn(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    _errorMessage = await _authService.signIn(email, password);

    if (_errorMessage == null) {
      final uid = _authService.currentUser?.uid;
      if (uid != null) {
        await loadAppUser(uid);
      }
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> signOut() async {
    final uid = _authService.currentUser?.uid;
    if (uid != null) {
      await NotificationService.instance.unregisterFcmToken(uid);
    }
    await _authService.signOut();
    _appUser = null;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
