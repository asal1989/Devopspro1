/// Centralized user-facing copy so wording stays consistent
/// and is easy to localize later.
class AppStrings {
  AppStrings._();

  static const String appName = 'Scanova';

  // Errors
  static const String cameraPermissionDenied =
      'Camera access is required to scan documents.';
  static const String ocrFailure =
      "We couldn't recognize the text. Try a clearer scan.";
  static const String detectionFailure =
      'Place the document on a flat surface and try again.';
  static const String storageFailure = 'Not enough storage available.';
  static const String offlineSaved =
      "You're offline. Your document has been saved locally.";
  static const String moveCloser = 'Move closer';
  static const String positionInFrame = 'Position the document inside the frame';
  static const String documentDetected = 'Document detected';
}
