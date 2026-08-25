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
/// [originalImagePath] points at the untouched capture (or gallery
/// import) on disk — it is never overwritten, so re-cropping or
/// re-filtering later always starts from the real original. When it is
/// null (e.g. Phase 1 sample documents, or a platform without camera
/// access), [originalAssetColor] is used as a placeholder thumbnail.
class ScanPage {
  final String id;
  final String? originalImagePath;
  final Color originalAssetColor;
  final List<Offset>? cropCorners;
  final int rotationDegrees;
  final PageFilter filter;
  final double brightness;
  final double contrast;
  final double sharpness;

  const ScanPage({
    required this.id,
    this.originalImagePath,
    this.originalAssetColor = const Color(0xFFEFEAE0),
    this.cropCorners,
    this.rotationDegrees = 0,
    this.filter = PageFilter.auto,
    this.brightness = 0,
    this.contrast = 0,
    this.sharpness = 0,
  });

  bool get hasRealImage => originalImagePath != null;

  ScanPage copyWith({
    String? originalImagePath,
    List<Offset>? cropCorners,
    int? rotationDegrees,
    PageFilter? filter,
    double? brightness,
    double? contrast,
    double? sharpness,
  }) {
    return ScanPage(
      id: id,
      originalImagePath: originalImagePath ?? this.originalImagePath,
      originalAssetColor: originalAssetColor,
      cropCorners: cropCorners ?? this.cropCorners,
      rotationDegrees: rotationDegrees ?? this.rotationDegrees,
      filter: filter ?? this.filter,
      brightness: brightness ?? this.brightness,
      contrast: contrast ?? this.contrast,
      sharpness: sharpness ?? this.sharpness,
    );
  }
}
