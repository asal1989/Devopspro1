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

  List<ScanPage> get pages => List.unmodifiable(_pages);
  int get pageCount => _pages.length;
  bool get isEmpty => _pages.isEmpty;

  ScanPage? get activePage =>
      _activePageIndex != null && _activePageIndex! < _pages.length ? _pages[_activePageIndex!] : null;

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

  void replacePage(int index, Color simulatedColor) {
    _pages[index] = ScanPage(id: _uuid.v4(), originalAssetColor: simulatedColor);
    notifyListeners();
  }

  void reset() {
    _pages.clear();
    _activePageIndex = null;
    notifyListeners();
  }
}
