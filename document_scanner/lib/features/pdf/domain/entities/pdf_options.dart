enum PdfPageFormat { a4, letter, original }

enum PdfQuality { low, medium, high }

/// Options collected on the PDF creation screen before a document is
/// generated and saved.
class PdfOptions {
  final String title;
  final PdfPageFormat format;
  final PdfQuality quality;
  final bool compress;
  final bool passwordProtected;
  final String? password;

  const PdfOptions({
    required this.title,
    this.format = PdfPageFormat.a4,
    this.quality = PdfQuality.high,
    this.compress = false,
    this.passwordProtected = false,
    this.password,
  });
}
