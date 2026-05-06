import 'package:firebase_auth/firebase_auth.dart';

class FirebaseAuthAPI {
  static final FirebaseAuth auth = FirebaseAuth.instance;

  Stream<User?> getUser() {
    return auth.authStateChanges();
  }

  User? get currentUser => auth.currentUser;

  Future<String?> signIn(String email, String password) async {
    try {
      await auth.signInWithEmailAndPassword(email: email, password: password);
      return null;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'invalid-credential' ||
          e.code == 'user-not-found' ||
          e.code == 'wrong-password') {
        return 'Invalid email or password.';
      } else if (e.code == 'invalid-email') {
        return 'Please enter a valid email address.';
      } else if (e.code == 'too-many-requests') {
        return 'Too many attempts. Please try again later.';
      }
      return e.message ?? 'An error occurred. Please try again.';
    }
  }

  Future<String?> signUp(
    String email,
    String password, {
    String? displayName,
  }) async {
    try {
      final credential = await auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (displayName != null && displayName.isNotEmpty) {
        await credential.user?.updateDisplayName(displayName);
      }
      return null;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'weak-password') {
        return 'Password is too weak.';
      } else if (e.code == 'email-already-in-use') {
        return 'An account already exists for that email.';
      } else if (e.code == 'invalid-email') {
        return 'Please enter a valid email address.';
      }
      return e.message ?? 'An error occurred. Please try again.';
    }
  }

  Future<void> signOut() async {
    await auth.signOut();
  }
}
