/// Result of AI document summarization.
class DocumentSummary {
  final String summary;
  final List<String> keyPoints;

  const DocumentSummary({required this.summary, this.keyPoints = const []});
}
