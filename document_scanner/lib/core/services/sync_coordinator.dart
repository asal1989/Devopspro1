import '../../features/authentication/presentation/providers/auth_provider.dart';
import '../../features/documents/data/sync/cloud_sync_repository.dart';
import '../../features/documents/data/sync/sync_service.dart';
import '../../features/documents/domain/entities/document.dart';
import '../../features/documents/presentation/providers/documents_provider.dart';
import '../../features/documents/presentation/providers/sync_status_provider.dart';
import '../../features/settings/presentation/providers/settings_provider.dart';

/// Connects the auth, settings, and documents providers to the sync
/// queue without any of them depending on each other directly.
///
/// Cloud sync only ever runs while [AuthProvider.isSignedIn] and
/// [SettingsProvider.cloudSyncEnabled] are both true; otherwise this is
/// entirely inert and every local feature (scan, edit, OCR, PDF) is
/// unaffected — matching the "offline first, cloud backup optional"
/// requirement. Created once in `main.dart` and kept alive for the
/// app's lifetime.
class SyncCoordinator {
  final AuthProvider auth;
  final SettingsProvider settings;
  final DocumentsProvider documents;
  final SyncStatusProvider status;
  final SyncService syncService;
  final CloudSyncRepository _repository;

  SyncCoordinator({
    required this.auth,
    required this.settings,
    required this.documents,
    required this.status,
    SyncService? syncService,
    CloudSyncRepository? repository,
  })  : syncService = syncService ?? SyncService(),
        _repository = repository ?? CloudSyncRepository() {
    documents.onDocumentChanged = _onDocumentChanged;
    documents.onDocumentDeleted = _onDocumentDeleted;
    auth.addListener(_onAuthOrSettingsChanged);
    settings.addListener(_onAuthOrSettingsChanged);
  }

  bool get _shouldSync => auth.isSignedIn && settings.cloudSyncEnabled;

  void _onDocumentChanged(ScannedDocument document) {
    if (!_shouldSync || document.isSynced) return;
    syncService.enqueue(document.id).then((_) => _drain());
  }

  void _onDocumentDeleted(String id) {
    if (!_shouldSync) return;
    final uid = auth.user?.uid;
    if (uid == null) return;
    // Fire-and-forget: CloudSyncRepository.deleteDocument already
    // swallows its own errors — a stray remote file is not fatal.
    // ignore: unawaited_futures
    _repository.deleteDocument(uid, id);
  }

  void _onAuthOrSettingsChanged() {
    if (_shouldSync) _drain();
  }

  /// Re-runs the queue on demand — used by Settings' "Retry" action.
  Future<void> retry() => _drain();

  Future<void> _drain() async {
    final uid = auth.user?.uid;
    if (uid == null) return;

    for (final doc in documents.all) {
      if (!doc.isSynced) await syncService.enqueue(doc.id);
    }

    status.update(isSyncing: true);
    await syncService.processQueue(uid: uid, documentsProvider: documents);
    status.update(
      isSyncing: false,
      pendingCount: await syncService.pendingCount(),
      failedCount: await syncService.failedCount(),
    );
  }

  void dispose() {
    auth.removeListener(_onAuthOrSettingsChanged);
    settings.removeListener(_onAuthOrSettingsChanged);
  }
}
