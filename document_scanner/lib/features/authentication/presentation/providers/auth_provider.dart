import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/auth_service.dart';
import '../../domain/entities/app_user.dart';

/// Tracks sign-in state for the whole app. Every screen that cares
/// whether someone is signed in (Settings, Sign In, the sync layer)
/// reads this instead of talking to Firebase directly.
class AuthProvider extends ChangeNotifier {
  final AuthService _authService;
  StreamSubscription<AppUser?>? _subscription;

  AppUser? user;
  bool isLoading = false;
  String? lastError;

  AuthProvider({AuthService? authService}) : _authService = authService ?? AuthService() {
    user = _authService.currentUser;
    _subscription = _authService.authStateChanges.listen((updated) {
      user = updated;
      notifyListeners();
    });
  }

  bool get isSignedIn => user != null;

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<bool> signInWithGoogle() => _run(_authService.signInWithGoogle);

  Future<bool> signInWithEmail(String email, String password) =>
      _run(() => _authService.signInWithEmail(email, password));

  Future<bool> signUpWithEmail(String email, String password) =>
      _run(() => _authService.signUpWithEmail(email, password));

  Future<bool> _run(Future<AppUser> Function() action) async {
    isLoading = true;
    lastError = null;
    notifyListeners();
    try {
      user = await action();
      return true;
    } catch (e) {
      lastError = e.toString();
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    await _authService.signOut();
    user = null;
    notifyListeners();
  }
}
