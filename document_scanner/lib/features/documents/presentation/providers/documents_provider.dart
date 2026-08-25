import 'package:flutter/material.dart';

import '../../data/mock_documents_repository.dart';
import '../../domain/entities/document.dart';

enum DocumentSort { newest, oldest, name, size }

/// Holds the in-memory document library for this session.
///
/// Backed by mock data in Phase 1; a real implementation later swaps
/// [MockDocumentsRepository] for a SQLite-backed repository behind the
/// same interface, so screens don't change.
class DocumentsProvider extends ChangeNotifier {
  final MockDocumentsRepository _repository;
  final List<ScannedDocument> _documents;

  DocumentsProvider({MockDocumentsRepository? repository})
      : _repository = repository ?? MockDocumentsRepository(),
        _documents = [] {
    _documents.addAll(_repository.loadSampleDocuments());
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
  }

  /// Replaces an existing document in place (same id), used when a
  /// saved document is re-opened for editing and re-saved.
  void updateDocument(ScannedDocument document) {
    final index = _documents.indexWhere((d) => d.id == document.id);
    if (index == -1) {
      _documents.insert(0, document);
    } else {
      _documents[index] = document;
    }
    notifyListeners();
  }

  void toggleFavorite(String id) {
    final index = _documents.indexWhere((d) => d.id == id);
    if (index == -1) return;
    _documents[index] = _documents[index].copyWith(isFavorite: !_documents[index].isFavorite);
    notifyListeners();
  }

  void rename(String id, String newName) {
    final index = _documents.indexWhere((d) => d.id == id);
    if (index == -1) return;
    _documents[index] = _documents[index].copyWith(name: newName);
    notifyListeners();
  }

  void delete(String id) {
    _documents.removeWhere((d) => d.id == id);
    notifyListeners();
  }

  void duplicate(String id) {
    final index = _documents.indexWhere((d) => d.id == id);
    if (index == -1) return;
    final source = _documents[index];
    _documents.insert(
      0,
      ScannedDocument(
        id: '${source.id}-copy-${DateTime.now().millisecondsSinceEpoch}',
        name: '${source.name} (Copy)',
        pages: source.pages,
        createdAt: DateTime.now(),
        sizeInKb: source.sizeInKb,
        category: source.category,
        thumbnailColor: source.thumbnailColor,
        extractedText: source.extractedText,
      ),
    );
    notifyListeners();
  }
}
