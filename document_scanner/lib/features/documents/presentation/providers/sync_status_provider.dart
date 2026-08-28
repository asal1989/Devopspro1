import 'package:flutter/material.dart';

/// Read-only view of cloud sync state for the UI — pending/failed
/// counts and whether a sync is running right now. Updated by
/// `SyncCoordinator`; nothing else writes to it.
class SyncStatusProvider extends ChangeNotifier {
  bool isSyncing = false;
  int pendingCount = 0;
  int failedCount = 0;

  void update({bool? isSyncing, int? pendingCount, int? failedCount}) {
    if (isSyncing != null) this.isSyncing = isSyncing;
    if (pendingCount != null) this.pendingCount = pendingCount;
    if (failedCount != null) this.failedCount = failedCount;
    notifyListeners();
  }
}
