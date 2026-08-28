import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../../../core/errors/app_exception.dart';
import '../domain/entities/ocr_result.dart';

/// Real, on-device text recognition via Google ML Kit — no network
/// required, satisfying the offline-first requirement.
///
/// ML Kit's on-device recognizer ships dedicated models for Latin,
/// Chinese, Devanagari, Japanese, and Korean scripts — Tamil and
/// Kannada are not among them. Until a cloud OCR fallback is added
/// (gated behind Premium, per the app's monetization plan), those two
/// languages fall back to the Latin recognizer: usable for mixed-script
/// documents and printed numerals/dates, but not a substitute for a
/// real Tamil/Kannada model. This is called out in the UI, not hidden.
class OcrService {
  final Map<TextRecognitionScript, TextRecognizer> _recognizers = {};

  TextRecognitionScript _scriptFor(OcrLanguage language) {
    switch (language) {
      case OcrLanguage.english:
        return TextRecognitionScript.latin;
      case OcrLanguage.hindi:
        return TextRecognitionScript.devanagiri;
      case OcrLanguage.tamil:
      case OcrLanguage.kannada:
        return TextRecognitionScript.latin;
    }
  }

  TextRecognizer _recognizerFor(OcrLanguage language) {
    final script = _scriptFor(language);
    return _recognizers.putIfAbsent(script, () => TextRecognizer(script: script));
  }

  /// Recognizes text in a single page image. Throws [OcrException] on
  /// failure — callers should catch it and show
  /// `AppStrings.ocrFailure` rather than letting it propagate.
  Future<String> recognizePage(String imagePath, OcrLanguage language) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final recognizer = _recognizerFor(language);
      final result = await recognizer.processImage(inputImage);
      return result.text;
    } catch (e) {
      throw OcrException("We couldn't recognize the text. Try a clearer scan.", cause: e);
    }
  }

  /// Recognizes text across every page and joins the results, so a
  /// multi-page document produces one continuous, readable transcript.
  Future<String> recognizeDocument(List<String> imagePaths, OcrLanguage language) async {
    if (imagePaths.isEmpty) return '';
    final pages = <String>[];
    for (final path in imagePaths) {
      final text = await recognizePage(path, language);
      if (text.trim().isNotEmpty) pages.add(text.trim());
    }
    return pages.join('\n\n');
  }

  Future<void> dispose() async {
    for (final recognizer in _recognizers.values) {
      await recognizer.close();
    }
    _recognizers.clear();
  }
}
