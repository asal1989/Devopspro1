import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Color, Offset;

import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart' as pdfpkg;
import 'package:pdf/widgets.dart' as pw;

import '../../scanner/data/image_processor.dart';
import '../../scanner/domain/entities/scan_page.dart';
import '../domain/entities/pdf_options.dart';

/// Per-page instructions for [generatePdfInIsolate]: either a real
/// captured image (processed exactly like the Enhancement screen
/// preview) or, for demo pages with no file, a flat placeholder in the
/// selected filter.
class PdfPageJob {
  final String? imagePath;
  final Color fallbackColor;
  final List<Offset>? cropCorners;
  final int rotationDegrees;
  final PageFilter filter;
  final double brightness;
  final double contrast;
  final double sharpness;

  const PdfPageJob({
    this.imagePath,
    this.fallbackColor = const Color(0xFFEFEAE0),
    this.cropCorners,
    this.rotationDegrees = 0,
    this.filter = PageFilter.auto,
    this.brightness = 0,
    this.contrast = 0,
    this.sharpness = 0,
  });
}

class GeneratePdfRequest {
  final List<PdfPageJob> pages;
  final PdfPageFormat format;
  final int jpegQuality;

  const GeneratePdfRequest({required this.pages, required this.format, this.jpegQuality = 85});
}

/// Builds a real multi-page PDF from processed page images. Designed to
/// run via `compute()` so multi-page (10-100 page) documents never
/// block the UI thread.
Future<Uint8List> generatePdfInIsolate(GeneratePdfRequest request) async {
  final doc = pw.Document();

  for (final job in request.pages) {
    final bytes = _buildPageBytes(job, request.jpegQuality);
    final image = pw.MemoryImage(bytes);
    final pageFormat = _resolvePageFormat(request.format, image);

    doc.addPage(
      pw.Page(
        pageFormat: pageFormat,
        margin: pw.EdgeInsets.zero,
        build: (context) => pw.Center(child: pw.Image(image, fit: pw.BoxFit.contain)),
      ),
    );
  }

  return doc.save();
}

Uint8List _buildPageBytes(PdfPageJob job, int quality) {
  final path = job.imagePath;
  if (path != null) {
    final sourceBytes = File(path).readAsBytesSync();
    return ImageProcessor.process(
      sourceBytes: sourceBytes,
      cropCorners: job.cropCorners,
      rotationDegrees: job.rotationDegrees,
      filter: job.filter,
      brightness: job.brightness,
      contrast: job.contrast,
      sharpness: job.sharpness,
      jpegQuality: quality,
    );
  }
  return _placeholderJpeg(job.fallbackColor, job.filter, quality);
}

Uint8List _placeholderJpeg(Color color, PageFilter filter, int quality) {
  final base = img.Image(width: 1240, height: 1754); // ~A4 at 150dpi
  img.fill(base, color: img.ColorRgb8(color.red, color.green, color.blue));
  final filtered = ImageProcessor.applyFilter(base, filter);
  return Uint8List.fromList(img.encodeJpg(filtered, quality: quality.clamp(10, 100)));
}

pdfpkg.PdfPageFormat _resolvePageFormat(PdfPageFormat format, pw.MemoryImage image) {
  switch (format) {
    case PdfPageFormat.a4:
      return pdfpkg.PdfPageFormat.a4;
    case PdfPageFormat.letter:
      return pdfpkg.PdfPageFormat.letter;
    case PdfPageFormat.original:
      const dpi = 150.0;
      final width = image.width.toDouble() / dpi * 72;
      final height = image.height.toDouble() / dpi * 72;
      return pdfpkg.PdfPageFormat(width, height);
  }
}
