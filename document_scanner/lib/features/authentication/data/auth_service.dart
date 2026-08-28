import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/services/firebase_bootstrap.dart';
import '../domain/entities/app_user.dart';

class AuthException extends AppException {
  const AuthException(super.message, {super.cause});
}

/// Wraps Firebase Auth (+ Google Sign-In) behind a small surface the
/// rest of the app depends on. Every method checks
/// [FirebaseBootstrap.isAvailable] first and throws a clear
/// [AuthException] instead of letting an unconfigured Firebase project
/// fail with an opaque platform-channel error — scanning, editing, OCR,
/// and PDF creation never require any of this to work.
class AuthService {
  final fb.FirebaseAuth _auth = fb.FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  Stream<AppUser?> get authStateChanges {
    if (!FirebaseBootstrap.isAvailable) return Stream.value(null);
    return _auth.authStateChanges().map(_mapUser);
  }

  AppUser? get currentUser => FirebaseBootstrap.isAvailable ? _mapUser(_auth.currentUser) : null;

  AppUser? _mapUser(fb.User? user) {
    if (user == null) return null;
    return AppUser(uid: user.uid, email: user.email, displayName: user.displayName, photoUrl: user.photoURL);
  }

  void _requireFirebase() {
    if (!FirebaseBootstrap.isAvailable) {
      throw const AuthException(
        'Cloud sign-in is not set up yet. This project needs a real Firebase '
        'config (see the README) before signing in.',
      );
    }
  }

  Future<AppUser> signInWithGoogle() async {
    _requireFirebase();
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        throw const AuthException('Sign-in was cancelled.');
      }
      final googleAuth = await googleUser.authentication;
      final credential = fb.GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final result = await _auth.signInWithCredential(credential);
      final user = _mapUser(result.user);
      if (user == null) throw const AuthException('Sign-in failed. Please try again.');
      return user;
    } on AuthException {
      rethrow;
    } on fb.FirebaseAuthException catch (e) {
      throw AuthException(_friendlyMessage(e), cause: e);
    } catch (e) {
      throw AuthException('Sign-in failed. Please try again.', cause: e);
    }
  }

  Future<AppUser> signUpWithEmail(String email, String password) async {
    _requireFirebase();
    try {
      final result = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      final user = _mapUser(result.user);
      if (user == null) throw const AuthException('Sign-up failed. Please try again.');
      return user;
    } on fb.FirebaseAuthException catch (e) {
      throw AuthException(_friendlyMessage(e), cause: e);
    } catch (e) {
      throw AuthException('Sign-up failed. Please try again.', cause: e);
    }
  }

  Future<AppUser> signInWithEmail(String email, String password) async {
    _requireFirebase();
    try {
      final result = await _auth.signInWithEmailAndPassword(email: email, password: password);
      final user = _mapUser(result.user);
      if (user == null) throw const AuthException('Sign-in failed. Please try again.');
      return user;
    } on fb.FirebaseAuthException catch (e) {
      throw AuthException(_friendlyMessage(e), cause: e);
    } catch (e) {
      throw AuthException('Sign-in failed. Please try again.', cause: e);
    }
  }

  Future<void> signOut() async {
    if (!FirebaseBootstrap.isAvailable) return;
    try {
      await _googleSignIn.signOut();
    } catch (_) {
      // Not signed in via Google, or already signed out — harmless.
    }
    await _auth.signOut();
  }

  String _friendlyMessage(fb.FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'That email address looks invalid.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'email-already-in-use':
        return 'An account already exists for that email.';
      case 'weak-password':
        return 'Choose a stronger password (at least 6 characters).';
      case 'network-request-failed':
        return "You're offline. Please check your connection and try again.";
      default:
        return 'Something went wrong. Please try again.';
    }
  }
}
