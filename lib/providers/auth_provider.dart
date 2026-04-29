import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../api/firebase_auth_api.dart';

class UserAuthProvider with ChangeNotifier {
  late FirebaseAuthAPI authService;
  late Stream<User?> uStream;
  String? errorMessage;

  UserAuthProvider() {
    authService = FirebaseAuthAPI();
    fetchAuthentication();
  }

  Stream<User?> get userStream => uStream;
  String? get error => errorMessage;

  void fetchAuthentication() {
    uStream = authService.getUser();
    notifyListeners();
  }

  Future<void> signUp(String email, String password) async {
    errorMessage = await authService.signUp(email, password);
    notifyListeners();
  }

  Future<void> signIn(String email, String password) async {
    errorMessage = await authService.signIn(email, password);
    notifyListeners();
  }

  Future<void> signOut() async {
    await authService.signOut();
    notifyListeners();
  }
}
