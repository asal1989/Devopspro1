import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/errors/app_exception.dart';
import '../domain/entities/ai_chat_message.dart';
import '../domain/entities/document_summary.dart';
import '../domain/entities/structured_extraction.dart';

/// Where the Dart client sends AI requests.
///
/// This intentionally points at a backend you deploy
/// ([functions/index.js](../../../../functions/index.js)), never
/// directly at `api.anthropic.com` — a real Anthropic API key must
/// never ship inside a mobile app binary, since anything embedded in a
/// compiled app can be extracted. See the README's Phase 7 section for
/// the one-time Firebase Cloud Functions deployment.
class AiConfig {
  AiConfig._();

  static const String backendBaseUrl = 'https://REPLACE_WITH_YOUR_DEPLOYED_FUNCTION_URL';

  static bool get isConfigured => !backendBaseUrl.contains('REPLACE_WITH');
}

/// Client for the AI features backend: summarization, Q&A, smart
/// classification, structured extraction, and natural-language search.
/// Every method throws [AiException] on failure instead of leaving a
/// screen stuck loading or crashing — callers show
/// `AiException.message` directly.
class AiService {
  final http.Client _client;

  AiService({http.Client? client}) : _client = client ?? http.Client();

  Future<Map<String, dynamic>> _call(String task, Map<String, dynamic> payload) async {
    if (!AiConfig.isConfigured) {
      throw const AiException(
        "AI features aren't set up yet. Deploy the Cloud Function in "
        "functions/ and point AiConfig.backendBaseUrl at it — see the README.",
      );
    }
    http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse('${AiConfig.backendBaseUrl}/$task'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 45));
    } catch (e) {
      throw AiException("Couldn't reach the AI service. Check your connection and try again.", cause: e);
    }

    if (response.statusCode != 200) {
      throw AiException('The AI request failed (HTTP ${response.statusCode}). Please try again.');
    }

    Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } catch (e) {
      throw AiException('The AI service returned an unexpected response.', cause: e);
    }
    if (decoded is! Map<String, dynamic>) {
      throw const AiException('The AI service returned an unexpected response.');
    }
    return decoded;
  }

  Future<DocumentSummary> summarize(String documentText) async {
    final result = await _call('summarize', {'text': documentText});
    return DocumentSummary(
      summary: (result['summary'] as String?)?.trim() ?? '',
      keyPoints: (result['keyPoints'] as List?)?.map((e) => e.toString()).toList() ?? const [],
    );
  }

  /// Returns a [DocumentCategory] enum name (e.g. `"invoice"`,
  /// `"receipt"`, `"general"`) — callers map it with
  /// `DocumentCategory.values.byName(...)`, falling back to `general`
  /// for anything unrecognized rather than throwing.
  Future<String> classify(String documentText) async {
    final result = await _call('classify', {'text': documentText});
    return (result['category'] as String?) ?? 'general';
  }

  Future<StructuredExtraction> extract(String documentText, ExtractionKind kind) async {
    final result = await _call('extract', {'text': documentText, 'kind': kind.apiValue});
    final rawFields = result['fields'];
    final fields = rawFields is Map
        ? rawFields.map((key, value) => MapEntry(key.toString(), value.toString()))
        : <String, String>{};
    return StructuredExtraction(fields);
  }

  Future<String> ask(String documentText, List<AiChatMessage> history, String question) async {
    final result = await _call('ask', {
      'text': documentText,
      'question': question,
      'history': history.map((m) => {'role': m.role.name, 'content': m.content}).toList(),
    });
    return (result['answer'] as String?)?.trim() ?? '';
  }

  /// Natural-language search over the library: given the user's query
  /// and a lightweight summary of each document (id, name, extracted
  /// text snippet), returns matching document ids ranked by relevance.
  Future<List<String>> search(String query, List<Map<String, String>> documents) async {
    final result = await _call('search', {'query': query, 'documents': documents});
    final matches = result['matchingIds'];
    return matches is List ? matches.map((e) => e.toString()).toList() : const [];
  }
}
