import 'package:flutter/material.dart';

import '../../data/database/documents_database.dart';
import '../../data/mock_documents_repository.dart';
import '../../domain/entities/document.dart';

enum DocumentSort { newest, oldest, name, size }

/// Holds the document library and keeps it in sync with SQLite.
///
/// On startup this loads whatever is already persisted; on a fresh
/// install (nothing in the database yet) it shows the mock sample
/// documents as demo content without writing them to disk, so a first
/// real save doesn't leave stale demo rows behind. Every mutation after
/// that is applied to the in-memory list immediately (so the UI never
/// waits on disk I/O) and persisted to [DocumentsDatabase] in the
/// background — a failed write never corrupts in-memory state or
/// crashes the app, matching the "storage failure" requirement.
class DocumentsProvider extends ChangeNotifier {
  final MockDocumentsRepository _mockRepository;
  final DocumentsDatabase _database;
  final List<ScannedDocument> _documents = [];
  bool _isReady = false;

  /// Fired after any add/update/rename/favorite/duplicate/OCR-result
  /// change, with the resulting document. Wired up in `main.dart` by
  /// `SyncCoordinator` to enqueue an upload when the user is signed in
  /// with Cloud Sync on — left null (no-op) otherwise, so this provider
  /// has no compile-time dependency on auth or sync.
  void Function(ScannedDocument document)? onDocumentChanged;

  /// Fired after a document is deleted locally, so the coordinator can
  /// best-effort remove the remote copy too.
  void Function(String documentId)? onDocumentDeleted;

  DocumentsProvider({MockDocumentsRepository? mockRepository, DocumentsDatabase? database})
      : _mockRepository = mockRepository ?? MockDocumentsRepository(),
        _database = database ?? DocumentsDatabase.instance {
    _bootstrap();
  }

  /// True once the initial load from disk has finished. Screens don't
  /// need to gate on this — mock demo content is shown immediately
  /// while the real load happens — but it's exposed for anything that
  /// wants to know (e.g. a future "syncing…" indicator).
  bool get isReady => _isReady;

  Future<void> _bootstrap() async {
    try {
      final stored = await _database.loadAll();
      if (stored.isEmpty) {
        _documents.addAll(_mockRepository.loadSampleDocuments());
      } else {
        _documents.addAll(stored);
      }
    } catch (_) {
      _documents.addAll(_mockRepository.loadSampleDocuments());
    }
    _isReady = true;
    notifyListeners();
  }

  void _persist(ScannedDocument document) {
    // ignore: unawaited_futures
    _database.upsert(document).catchError((_) {});
  }

  void _remove(String id) {
    // ignore: unawaited_futures
    _database.delete(id).catchError((_) {});
  }

  List<ScannedDocument> get all => List.unmodifiable(_documents);

  List<ScannedDocument> get recent {
    final sorted = [..._documents]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted.take(4).toList();
  }

  List<ScannedDocument> get favorites => _documents.where((d) => d.isFavorite).toList();

  List<ScannedDocument> search(String query) {
    if (query.trim().isEmpty) return all;
    final lower = query.toLowerCase();
    return _documents.where((d) => d.name.toLowerCase().contains(lower)).toList();
  }

  List<ScannedDocument> sorted(List<ScannedDocument> docs, DocumentSort sort) {
    final list = [...docs];
    switch (sort) {
      case DocumentSort.newest:
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case DocumentSort.oldest:
        list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
      case DocumentSort.name:
        list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
      case DocumentSort.size:
        list.sort((a, b) => b.sizeInKb.compareTo(a.sizeInKb));
        break;
    }
    return list;
  }

  void addDocument(ScannedDocument document) {
    _documents.insert(0, document);
    notifyListeners();
    _persist(document);
    onDocumentChanged?.call(document);
  }

  /// Replaces an existing document in place (same id), used when a
  /// saved document is re-opened for editing and re-saved, and by
  /// `SyncService` to record a successful upload.
  void updateDocument(ScannedDocument document) {
    final index = _documents.indexWhere((d) => d.id == document.id);
    if (index == -1) {
      _documents.insert(0, document);
    } else {
      _documents[index] = document;
    }
    notifyListeners();
    _persist(document);
    onDocumentChanged?.call(document);
  }

  void toggleFavorite(String id) {
    final index = _documents.indexWhere((d) => d.id == id);
    if (index == -1) return;
    _documents[index] = _documents[index].copyWith(isFavorite: !_documents[index].isFavorite);
    notifyListeners();
    _persist(_documents[index]);
    onDocumentChanged?.call(_documents[index]);
  }

  void rename(String id, String newName) {
    final index = _documents.indexWhere((d) => d.id == id);
    if (index == -1) return;
    _documents[index] = _documents[index].copyWith(name: newName);
    notifyListeners();
    _persist(_documents[index]);
    onDocumentChanged?.call(_documents[index]);
  }

  /// Sets extracted OCR text on a document and persists it, so re-opening
  /// the document later doesn't need to re-run recognition.
  void setExtractedText(String id, String text) {
    final index = _documents.indexWhere((d) => d.id == id);
    if (index == -1) return;
    _documents[index] = _documents[index].copyWith(extractedText: text);
    notifyListeners();
    _persist(_documents[index]);
    onDocumentChanged?.call(_documents[index]);
  }

  void delete(String id) {
    _documents.removeWhere((d) => d.id == id);
    notifyListeners();
    _remove(id);
    onDocumentDeleted?.call(id);
  }

  void duplicate(String id) {
    final index = _documents.indexWhere((d) => d.id == id);
    if (index == -1) return;
    final source = _documents[index];
    final copy = ScannedDocument(
      id: '${source.id}-copy-${DateTime.now().millisecondsSinceEpoch}',
      name: '${source.name} (Copy)',
      pages: source.pages,
      createdAt: DateTime.now(),
      sizeInKb: source.sizeInKb,
      category: source.category,
      thumbnailColor: source.thumbnailColor,
      extractedText: source.extractedText,
      pdfPath: source.pdfPath,
    );
    _documents.insert(0, copy);
    notifyListeners();
    _persist(copy);
    onDocumentChanged?.call(copy);
  }
}
