import 'package:flutter/foundation.dart';

import '../../domain/entities/document.dart';
import '../../presentation/providers/documents_provider.dart';
import '../database/documents_database.dart';
import 'cloud_sync_repository.dart';

/// Drains the offline-first upload queue: for every pending or
/// previously-failed document, retries the upload, tracking a retry
/// count and the last error so Settings can show real sync status.
///
/// Only ever runs while a user is signed in and has opted into Cloud
/// Sync (see `SyncCoordinator`, which decides *when* to call this) —
/// local scanning/editing/PDF/OCR never depend on it, and a failed
/// upload never blocks or corrupts local data.
class SyncService {
  final CloudSyncRepository _repository;
  final DocumentsDatabase _database;

  bool _isProcessing = false;
  bool get isProcessing => _isProcessing;

  SyncService({CloudSyncRepository? repository, DocumentsDatabase? database})
      : _repository = repository ?? CloudSyncRepository(),
        _database = database ?? DocumentsDatabase.instance;

  Future<void> enqueue(String documentId) => _database.enqueueForSync(documentId);

  Future<int> pendingCount() async => (await _database.pendingSyncEntries()).length;

  Future<int> failedCount() async =>
      (await _database.pendingSyncEntries()).where((e) => e.status == SyncQueueStatus.failed).length;

  /// Attempts to upload every queued document. Safe to call repeatedly
  /// (a Retry button, right after sign-in, or after toggling sync on)
  /// — a concurrent call is a no-op rather than racing the first one.
  Future<void> processQueue({required String uid, required DocumentsProvider documentsProvider}) async {
    if (_isProcessing) return;
    _isProcessing = true;
    try {
      final entries = await _database.pendingSyncEntries();
      for (final entry in entries) {
        ScannedDocument? document;
        for (final d in documentsProvider.all) {
          if (d.id == entry.documentId) {
            document = d;
            break;
          }
        }
        if (document == null) {
          // Deleted locally before it ever synced — nothing to upload.
          await _database.dequeue(entry.documentId);
          continue;
        }

        await _database.markSyncStatus(entry.documentId, SyncQueueStatus.uploading);
        try {
          await _repository.uploadDocument(uid, document);
          final synced = document.copyWith(syncedAt: DateTime.now(), touchUpdatedAt: false);
          documentsProvider.updateDocument(synced);
          await _database.dequeue(entry.documentId);
        } catch (e) {
          await _database.markSyncStatus(
            entry.documentId,
            SyncQueueStatus.failed,
            error: e.toString(),
            retryCount: entry.retryCount + 1,
          );
          debugPrint('Sync failed for ${entry.documentId}: $e');
        }
      }
    } finally {
      _isProcessing = false;
    }
  }
}
