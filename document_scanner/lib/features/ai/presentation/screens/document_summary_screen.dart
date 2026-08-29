import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../documents/domain/entities/document.dart';
import '../../../documents/presentation/providers/documents_provider.dart';
import '../../data/ai_service.dart';
import '../../domain/entities/document_summary.dart';

/// AI document summarization, plus a "smart classification" suggestion
/// the user can apply with one tap — both single Claude calls over the
/// document's OCR text, per the AI Features architecture.
class DocumentSummaryScreen extends StatefulWidget {
  final ScannedDocument document;
  const DocumentSummaryScreen({super.key, required this.document});

  @override
  State<DocumentSummaryScreen> createState() => _DocumentSummaryScreenState();
}

class _DocumentSummaryScreenState extends State<DocumentSummaryScreen> {
  final _aiService = AiService();
  bool _loading = false;
  String? _error;
  DocumentSummary? _summary;

  bool _classifying = false;
  DocumentCategory? _suggestedCategory;

  @override
  void initState() {
    super.initState();
    if ((widget.document.extractedText ?? '').trim().isNotEmpty) {
      _runSummarize();
    }
  }

  Future<void> _runSummarize() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final summary = await _aiService.summarize(widget.document.extractedText!);
      if (!mounted) return;
      setState(() {
        _summary = summary;
        _loading = false;
      });
    } on AiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  Future<void> _suggestCategory() async {
    setState(() => _classifying = true);
    try {
      final raw = await _aiService.classify(widget.document.extractedText!);
      var category = DocumentCategory.general;
      for (final c in DocumentCategory.values) {
        if (c.name == raw) {
          category = c;
          break;
        }
      }
      if (!mounted) return;
      setState(() {
        _suggestedCategory = category;
        _classifying = false;
      });
    } on AiException catch (e) {
      if (!mounted) return;
      setState(() => _classifying = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  void _applyCategory() {
    final category = _suggestedCategory;
    if (category == null) return;
    context.read<DocumentsProvider>().updateDocument(widget.document.copyWith(category: category));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Category updated')));
  }

  @override
  Widget build(BuildContext context) {
    final hasText = (widget.document.extractedText ?? '').trim().isNotEmpty;
    final secondary = Theme.of(context).extension<AppSemanticColors>()?.textSecondary;

    return Scaffold(
      appBar: AppBar(title: const Text('AI Summary')),
      body: !hasText
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Text(
                  'Extract text from this document first (Extract Text on the PDF Preview screen), '
                  'then come back here to summarize it.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: secondary),
                ),
              ),
            )
          : _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_error!, textAlign: TextAlign.center),
                            const SizedBox(height: AppSpacing.md),
                            OutlinedButton(onPressed: _runSummarize, child: const Text('Try Again')),
                          ],
                        ),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      children: [
                        Text('Summary', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: AppSpacing.sm),
                        Text(_summary?.summary ?? '', style: const TextStyle(height: 1.5)),
                        if ((_summary?.keyPoints ?? const []).isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.lg),
                          Text('Key Points', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                          const SizedBox(height: AppSpacing.sm),
                          ...(_summary!.keyPoints.map((point) => Padding(
                                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('•  '),
                                    Expanded(child: Text(point)),
                                  ],
                                ),
                              ))),
                        ],
                        const SizedBox(height: AppSpacing.xl),
                        const Divider(),
                        const SizedBox(height: AppSpacing.md),
                        Text('Smart Classification', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: AppSpacing.sm),
                        if (_suggestedCategory == null)
                          OutlinedButton.icon(
                            onPressed: _classifying ? null : _suggestCategory,
                            icon: _classifying
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.auto_awesome_rounded),
                            label: const Text('Suggest a category'),
                          )
                        else
                          Row(
                            children: [
                              Chip(label: Text(_suggestedCategory!.name)),
                              const SizedBox(width: AppSpacing.sm),
                              TextButton(onPressed: _applyCategory, child: const Text('Apply')),
                            ],
                          ),
                      ],
                    ),
    );
  }
}
