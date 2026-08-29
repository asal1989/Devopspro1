/// Kinds of structured extraction the AI backend supports. Kept as an
/// explicit enum (rather than a free-text string) so the backend
/// prompt and the UI's field labels stay in lockstep.
enum ExtractionKind { invoice, receipt, general }

extension ExtractionKindApi on ExtractionKind {
  String get apiValue => name;
}

/// Generic key/value fields pulled from a document — vendor, invoice
/// number, amount, date, or whatever the requested [ExtractionKind]
/// asks for. Kept as a flat string map rather than rigid per-document-
/// type classes since the real field set genuinely varies (an invoice
/// has a PO number, a receipt doesn't).
class StructuredExtraction {
  final Map<String, String> fields;

  const StructuredExtraction(this.fields);

  bool get isEmpty => fields.isEmpty;
}
