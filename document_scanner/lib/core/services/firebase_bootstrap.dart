import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../../firebase_options.dart';

/// Initializes Firebase once at startup and remembers whether it
/// actually succeeded.
///
/// The app must keep working fully offline with no account at all (per
/// the "offline first" requirement), so a missing/placeholder Firebase
/// config must never crash startup — [initialize] swallows the failure
/// and [isAvailable] lets auth/sync code refuse gracefully afterward
/// instead of throwing deep inside a Firebase SDK call.
class FirebaseBootstrap {
  FirebaseBootstrap._();

  static bool isAvailable = false;

  static Future<void> initialize() async {
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      isAvailable = true;
    } catch (e) {
      isAvailable = false;
      debugPrint('Firebase not configured — running in local-only mode. ($e)');
    }
  }
}
