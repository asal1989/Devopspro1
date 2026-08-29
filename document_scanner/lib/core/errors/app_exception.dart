/// Base type for recoverable, user-facing failures.
///
/// UI layers catch these and render a friendly message instead of
/// letting camera/OCR/PDF/network failures crash the app.
class AppException implements Exception {
  final String message;
  final Object? cause;

  const AppException(this.message, {this.cause});

  @override
  String toString() => message;
}

class CameraException extends AppException {
  const CameraException(super.message, {super.cause});
}

class DocumentDetectionException extends AppException {
  const DocumentDetectionException(super.message, {super.cause});
}

class OcrException extends AppException {
  const OcrException(super.message, {super.cause});
}

class PdfGenerationException extends AppException {
  const PdfGenerationException(super.message, {super.cause});
}

class StorageException extends AppException {
  const StorageException(super.message, {super.cause});
}

class NetworkException extends AppException {
  const NetworkException(super.message, {super.cause});
}

class AiException extends AppException {
  const AiException(super.message, {super.cause});
}
