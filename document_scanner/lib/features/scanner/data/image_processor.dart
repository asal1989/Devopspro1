import 'dart:typed_data';
import 'dart:ui' show Offset;

import 'package:image/image.dart' as img;

import '../domain/entities/scan_page.dart';

/// Argument bundle for [processPageInIsolate] — `compute()` requires a
/// single top-level function taking one argument, so page processing
/// options are packed into this class rather than passed positionally.
class ProcessPageRequest {
  final Uint8List sourceBytes;
  final List<Offset>? cropCorners;
  final int rotationDegrees;
  final PageFilter filter;
  final double brightness;
  final double contrast;
  final double sharpness;
  final int jpegQuality;

  const ProcessPageRequest({
    required this.sourceBytes,
    this.cropCorners,
    this.rotationDegrees = 0,
    this.filter = PageFilter.auto,
    this.brightness = 0,
    this.contrast = 0,
    this.sharpness = 0,
    this.jpegQuality = 90,
  });
}

/// Top-level entry point so this work can run via `compute()` on a
/// background isolate — keeps the UI thread free while processing
/// large or many-page documents.
Uint8List processPageInIsolate(ProcessPageRequest request) {
  return ImageProcessor.process(
    sourceBytes: request.sourceBytes,
    cropCorners: request.cropCorners,
    rotationDegrees: request.rotationDegrees,
    filter: request.filter,
    brightness: request.brightness,
    contrast: request.contrast,
    sharpness: request.sharpness,
    jpegQuality: request.jpegQuality,
  );
}

/// Real (non-simulated) pixel-level processing for a captured page:
/// perspective correction from the four crop corners, rotation, filter
/// presets, and brightness/contrast/sharpness adjustment.
///
/// Runs on plain `Uint8List` in and out so callers can invoke it inside
/// an isolate via `compute()` for large/multi-page jobs without
/// blocking the UI thread.
class ImageProcessor {
  ImageProcessor._();

  /// Longest side a working image is downscaled to before any filter or
  /// warp runs. Keeps processing fast and memory-bounded on mid-range
  /// phones even for very large camera captures.
  static const int maxWorkingDimension = 2200;

  static Uint8List process({
    required Uint8List sourceBytes,
    List<Offset>? cropCorners,
    int rotationDegrees = 0,
    PageFilter filter = PageFilter.auto,
    double brightness = 0,
    double contrast = 0,
    double sharpness = 0,
    int jpegQuality = 90,
  }) {
    img.Image? decoded = img.decodeImage(sourceBytes);
    if (decoded == null) return sourceBytes;

    final longestSide = decoded.width > decoded.height ? decoded.width : decoded.height;
    if (longestSide > maxWorkingDimension) {
      decoded = decoded.width >= decoded.height
          ? img.copyResize(decoded, width: maxWorkingDimension)
          : img.copyResize(decoded, height: maxWorkingDimension);
    }

    var working = decoded;

    if (cropCorners != null && cropCorners.length == 4) {
      working = perspectiveCrop(working, cropCorners);
    }

    if (rotationDegrees % 360 != 0) {
      working = img.copyRotate(working, angle: rotationDegrees);
    }

    working = applyFilter(working, filter);
    working = adjust(working, brightness: brightness, contrast: contrast, sharpness: sharpness);

    return Uint8List.fromList(img.encodeJpg(working, quality: jpegQuality.clamp(10, 100)));
  }

  /// Warps the quadrilateral defined by [corners] (normalized 0..1,
  /// ordered top-left, top-right, bottom-right, bottom-left) in
  /// [source] into an upright rectangle — corrects perspective,
  /// rotation, skew, and uneven positioning in one pass.
  static img.Image perspectiveCrop(img.Image source, List<Offset> corners) {
    final srcPoints = corners.map((c) => Offset(c.dx * source.width, c.dy * source.height)).toList();

    final topWidth = (srcPoints[1] - srcPoints[0]).distance;
    final bottomWidth = (srcPoints[2] - srcPoints[3]).distance;
    final leftHeight = (srcPoints[3] - srcPoints[0]).distance;
    final rightHeight = (srcPoints[2] - srcPoints[1]).distance;

    final outWidth = _clampDimension(topWidth > bottomWidth ? topWidth : bottomWidth);
    final outHeight = _clampDimension(leftHeight > rightHeight ? leftHeight : rightHeight);

    final output = img.Image(width: outWidth, height: outHeight);

    for (var y = 0; y < outHeight; y++) {
      final v = outHeight <= 1 ? 0.0 : y / (outHeight - 1);
      final left = Offset.lerp(srcPoints[0], srcPoints[3], v)!;
      final right = Offset.lerp(srcPoints[1], srcPoints[2], v)!;
      for (var x = 0; x < outWidth; x++) {
        final u = outWidth <= 1 ? 0.0 : x / (outWidth - 1);
        final sample = Offset.lerp(left, right, u)!;
        output.setPixel(x, y, _sampleBilinear(source, sample.dx, sample.dy));
      }
    }
    return output;
  }

  static int _clampDimension(double value) {
    final v = value.round();
    if (v < 1) return 1;
    if (v > 6000) return 6000;
    return v;
  }

  static img.Color _sampleBilinear(img.Image source, double x, double y) {
    final x0 = x.floor().clamp(0, source.width - 1);
    final y0 = y.floor().clamp(0, source.height - 1);
    final x1 = (x0 + 1).clamp(0, source.width - 1);
    final y1 = (y0 + 1).clamp(0, source.height - 1);
    final dx = x - x0;
    final dy = y - y0;

    final c00 = source.getPixel(x0, y0);
    final c10 = source.getPixel(x1, y0);
    final c01 = source.getPixel(x0, y1);
    final c11 = source.getPixel(x1, y1);

    double lerp(num a, num b, double t) => a + (b - a) * t;

    final r = lerp(lerp(c00.r, c10.r, dx), lerp(c01.r, c11.r, dx), dy).round().clamp(0, 255);
    final g = lerp(lerp(c00.g, c10.g, dx), lerp(c01.g, c11.g, dx), dy).round().clamp(0, 255);
    final b = lerp(lerp(c00.b, c10.b, dx), lerp(c01.b, c11.b, dx), dy).round().clamp(0, 255);

    return img.ColorRgb8(r, g, b);
  }

  static img.Image applyFilter(img.Image source, PageFilter filter) {
    switch (filter) {
      case PageFilter.grayscale:
        return img.grayscale(source);
      case PageFilter.blackAndWhite:
        return _threshold(source);
      case PageFilter.highContrast:
        return img.adjustColor(source, contrast: 1.35, saturation: 1.1);
      case PageFilter.document:
        return img.adjustColor(source, contrast: 1.15, brightness: 1.05, saturation: 0.85);
      case PageFilter.auto:
        return img.adjustColor(source, contrast: 1.1, brightness: 1.02, saturation: 1.05);
      case PageFilter.original:
      case PageFilter.color:
        return source;
    }
  }

  static img.Image _threshold(img.Image source, {int cutoff = 140}) {
    final gray = img.grayscale(source);
    final out = img.Image(width: gray.width, height: gray.height);
    for (var y = 0; y < gray.height; y++) {
      for (var x = 0; x < gray.width; x++) {
        final value = gray.getPixel(x, y).r > cutoff ? 255 : 0;
        out.setPixel(x, y, img.ColorRgb8(value, value, value));
      }
    }
    return out;
  }

  /// [brightness] and [contrast] are on the -50..50 scale used by the
  /// Enhancement screen sliders; [sharpness] is 0..50.
  static img.Image adjust(
    img.Image source, {
    double brightness = 0,
    double contrast = 0,
    double sharpness = 0,
  }) {
    var result = source;
    if (brightness != 0 || contrast != 0) {
      result = img.adjustColor(
        result,
        brightness: 1 + brightness / 100,
        contrast: 1 + contrast / 100,
      );
    }
    if (sharpness > 0) {
      result = _sharpen(result, (sharpness / 50).clamp(0.0, 1.0));
    }
    return result;
  }

  static img.Image _sharpen(img.Image source, double amount) {
    if (amount <= 0) return source;
    final kernel = [
      0.0, -amount, 0.0,
      -amount, 1 + 4 * amount, -amount,
      0.0, -amount, 0.0,
    ];
    final out = img.Image(width: source.width, height: source.height);
    for (var y = 0; y < source.height; y++) {
      for (var x = 0; x < source.width; x++) {
        double r = 0, g = 0, b = 0;
        var k = 0;
        for (var ky = -1; ky <= 1; ky++) {
          for (var kx = -1; kx <= 1; kx++) {
            final sx = (x + kx).clamp(0, source.width - 1);
            final sy = (y + ky).clamp(0, source.height - 1);
            final p = source.getPixel(sx, sy);
            final w = kernel[k++];
            r += p.r * w;
            g += p.g * w;
            b += p.b * w;
          }
        }
        out.setPixel(
          x,
          y,
          img.ColorRgb8(r.round().clamp(0, 255), g.round().clamp(0, 255), b.round().clamp(0, 255)),
        );
      }
    }
    return out;
  }
}
