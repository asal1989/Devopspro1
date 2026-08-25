import 'package:flutter/material.dart';

/// App-wide user preferences. Held in memory for Phase 1; a later phase
/// persists this via SQLite/shared_preferences behind the same API.
class SettingsProvider extends ChangeNotifier {
  ThemeMode themeMode = ThemeMode.system;
  bool autoCapture = true;
  String defaultFilter = 'Auto';
  String defaultPdfQuality = 'High';
  bool autoOcr = false;
  bool saveOriginalImage = true;
  bool cloudSyncEnabled = false;
  bool isSignedIn = false;
  String? userEmail;

  void setThemeMode(ThemeMode mode) {
    themeMode = mode;
    notifyListeners();
  }

  void toggleAutoCapture(bool value) {
    autoCapture = value;
    notifyListeners();
  }

  void setDefaultFilter(String value) {
    defaultFilter = value;
    notifyListeners();
  }

  void setDefaultPdfQuality(String value) {
    defaultPdfQuality = value;
    notifyListeners();
  }

  void toggleAutoOcr(bool value) {
    autoOcr = value;
    notifyListeners();
  }

  void toggleSaveOriginal(bool value) {
    saveOriginalImage = value;
    notifyListeners();
  }

  void toggleCloudSync(bool value) {
    cloudSyncEnabled = value;
    notifyListeners();
  }

  void signIn(String email) {
    isSignedIn = true;
    userEmail = email;
    notifyListeners();
  }

  void signOut() {
    isSignedIn = false;
    userEmail = null;
    cloudSyncEnabled = false;
    notifyListeners();
  }
}
