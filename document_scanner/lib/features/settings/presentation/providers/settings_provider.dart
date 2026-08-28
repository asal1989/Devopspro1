import 'package:flutter/material.dart';

/// App-wide user preferences. Held in memory for now; a later pass
/// persists this via shared_preferences behind the same API.
///
/// Sign-in state itself lives in `AuthProvider`, not here — this only
/// tracks whether the user has *opted in* to cloud sync, which is a
/// preference independent of being signed in (Settings disables the
/// toggle when signed out; see `SettingsScreen`).
class SettingsProvider extends ChangeNotifier {
  ThemeMode themeMode = ThemeMode.system;
  bool autoCapture = true;
  String defaultFilter = 'Auto';
  String defaultPdfQuality = 'High';
  bool autoOcr = false;
  bool saveOriginalImage = true;
  bool cloudSyncEnabled = false;

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

  /// Called by `AuthProvider`-driven sign-out flows so re-signing-in
  /// later starts from a clean slate rather than resuming a stale sync
  /// preference for a different account.
  void resetCloudSync() {
    cloudSyncEnabled = false;
    notifyListeners();
  }
}
