import 'package:flutter/material.dart';

/// Enhancement filter applied to a scanned page.
enum PageFilter { auto, original, color, grayscale, blackAndWhite, document, highContrast }

extension PageFilterLabel on PageFilter {
  String get label {
    switch (this) {
      case PageFilter.auto:
        return 'Auto';
      case PageFilter.original:
        return 'Original';
      case PageFilter.color:
        return 'Color';
      case PageFilter.grayscale:
        return 'Grayscale';
      case PageFilter.blackAndWhite:
        return 'Black & White';
      case PageFilter.document:
        return 'Document';
      case PageFilter.highContrast:
        return 'High Contrast';
    }
  }
}

/// A single captured/scanned page within a document session.
///
/// [originalAssetColor] stands in for the original captured image in this
/// UI prototype (Phase 1 uses mock data, not real camera frames).
class ScanPage {
  final String id;
  final Color originalAssetColor;
  final int rotationDegrees;
  final PageFilter filter;
  final double brightness;
  final double contrast;
  final double sharpness;

  const ScanPage({
    required this.id,
    required this.originalAssetColor,
    this.rotationDegrees = 0,
    this.filter = PageFilter.auto,
    this.brightness = 0,
    this.contrast = 0,
    this.sharpness = 0,
  });

  ScanPage copyWith({
    int? rotationDegrees,
    PageFilter? filter,
    double? brightness,
    double? contrast,
    double? sharpness,
  }) {
    return ScanPage(
      id: id,
      originalAssetColor: originalAssetColor,
      rotationDegrees: rotationDegrees ?? this.rotationDegrees,
      filter: filter ?? this.filter,
      brightness: brightness ?? this.brightness,
      contrast: contrast ?? this.contrast,
      sharpness: sharpness ?? this.sharpness,
    );
  }
}
