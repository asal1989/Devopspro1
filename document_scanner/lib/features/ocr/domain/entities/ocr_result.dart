enum OcrLanguage { english, tamil, kannada, hindi }

extension OcrLanguageLabel on OcrLanguage {
  String get label {
    switch (this) {
      case OcrLanguage.english:
        return 'English';
      case OcrLanguage.tamil:
        return 'Tamil';
      case OcrLanguage.kannada:
        return 'Kannada';
      case OcrLanguage.hindi:
        return 'Hindi';
    }
  }
}
