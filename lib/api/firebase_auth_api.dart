import 'package:firebase_auth/firebase_auth.dart';

class FirebaseAuthAPI {
  static final FirebaseAuth auth = FirebaseAuth.instance;

  Stream<User?> getUser() {
    return auth.authStateChanges();
  }

  Future<String?> signIn(String email, String password) async {
    try {
      await auth.signInWithEmailAndPassword(email: email, password: password);
      return null; // null means success
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        return 'No account found for that email.';
      } else if (e.code == 'wrong-password') {
        return 'Incorrect password.';
      }
      return e.message;
    }
  }

  Future<String?> signUp(String email, String password) async {
    try {
      await auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return null;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'weak-password') {
        return 'Password is too weak.';
      } else if (e.code == 'email-already-in-use') {
        return 'An account already exists for that email.';
      }
      return e.message;
    }
  }

  Future<void> signOut() async {
    await auth.signOut();
  }
}
