import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/scan_page.dart';

/// Tracks the pages captured during an in-progress multi-page scan,
/// from first capture through crop, enhancement, and page management,
/// until the document is saved or discarded.
class ScanSessionProvider extends ChangeNotifier {
  final _uuid = const Uuid();
  final List<ScanPage> _pages = [];
  int? _activePageIndex;

  /// Set while re-opening an already-saved document for editing (Add
  /// page / Reorder / Edit page from the PDF Preview screen), so
  /// finishing the flow updates that document instead of creating a
  /// new one. Null for a brand new scan.
  String? editingDocumentId;

  List<ScanPage> get pages => List.unmodifiable(_pages);
  int get pageCount => _pages.length;
  bool get isEmpty => _pages.isEmpty;

  ScanPage? get activePage =>
      _activePageIndex != null && _activePageIndex! < _pages.length ? _pages[_activePageIndex!] : null;

  /// Adds a page captured (or imported) as a real image file on disk.
  void capturePageFromFile(String imagePath) {
    _pages.add(ScanPage(id: _uuid.v4(), originalImagePath: imagePath));
    _activePageIndex = _pages.length - 1;
    notifyListeners();
  }

  /// Adds a placeholder page with no real image — used only for demos
  /// and previews where no camera/file is available.
  void capturePage(Color simulatedColor) {
    _pages.add(ScanPage(id: _uuid.v4(), originalAssetColor: simulatedColor));
    _activePageIndex = _pages.length - 1;
    notifyListeners();
  }

  void setActivePage(int index) {
    _activePageIndex = index;
    notifyListeners();
  }

  void updateActivePage(ScanPage updated) {
    if (_activePageIndex == null) return;
    _pages[_activePageIndex!] = updated;
    notifyListeners();
  }

  void rotatePage(int index) {
    final page = _pages[index];
    _pages[index] = page.copyWith(rotationDegrees: (page.rotationDegrees + 90) % 360);
    notifyListeners();
  }

  void deletePage(int index) {
    _pages.removeAt(index);
    if (_activePageIndex != null && _activePageIndex! >= _pages.length) {
      _activePageIndex = _pages.isEmpty ? null : _pages.length - 1;
    }
    notifyListeners();
  }

  void reorderPage(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex -= 1;
    final page = _pages.removeAt(oldIndex);
    _pages.insert(newIndex, page);
    notifyListeners();
  }

  void replacePageWithFile(int index, String imagePath) {
    _pages[index] = ScanPage(id: _uuid.v4(), originalImagePath: imagePath);
    notifyListeners();
  }

  /// Loads an existing document's pages back into the session for
  /// editing. [documentId] is remembered so the PDF creation step
  /// updates that document instead of creating a new one.
  void loadForEditing(String documentId, List<ScanPage> existingPages) {
    _pages
      ..clear()
      ..addAll(existingPages);
    _activePageIndex = _pages.isEmpty ? null : 0;
    editingDocumentId = documentId;
    notifyListeners();
  }

  void reset() {
    _pages.clear();
    _activePageIndex = null;
    editingDocumentId = null;
    notifyListeners();
  }
}
