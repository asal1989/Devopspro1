import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../documents/domain/entities/document.dart';
import '../../data/ai_service.dart';
import '../../domain/entities/structured_extraction.dart';

/// Structured extraction — invoice fields (vendor, invoice number,
/// amount, date), receipt fields, or a general names/dates/amounts
/// pass, per the AI Features spec's invoice/receipt extraction example.
class ExtractionScreen extends StatefulWidget {
  final ScannedDocument document;
  const ExtractionScreen({super.key, required this.document});

  @override
  State<ExtractionScreen> createState() => _ExtractionScreenState();
}

class _ExtractionScreenState extends State<ExtractionScreen> {
  final _aiService = AiService();
  ExtractionKind _kind = ExtractionKind.invoice;
  bool _loading = false;
  String? _error;
  StructuredExtraction? _result;

  bool get _hasText => (widget.document.extractedText ?? '').trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    if (_hasText) _run();
  }

  Future<void> _run() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _aiService.extract(widget.document.extractedText!, _kind);
      if (!mounted) return;
      setState(() {
        _result = result;
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

  void _copyAll() {
    final fields = _result?.fields ?? const {};
    final text = fields.entries.map((e) => '${e.key}: ${e.value}').join('\n');
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied')));
  }

  @override
  Widget build(BuildContext context) {
    final secondary = Theme.of(context).extension<AppSemanticColors>()?.textSecondary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Extract Information'),
        actions: [
          if (_result != null && !(_result!.isEmpty))
            IconButton(icon: const Icon(Icons.copy_rounded), onPressed: _copyAll, tooltip: 'Copy all'),
        ],
      ),
      body: !_hasText
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Text(
                  'Extract text from this document first, then come back to pull out structured fields.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: secondary),
                ),
              ),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Wrap(
                    spacing: AppSpacing.sm,
                    children: [
                      ChoiceChip(
                        label: const Text('Invoice'),
                        selected: _kind == ExtractionKind.invoice,
                        onSelected: (_) {
                          setState(() => _kind = ExtractionKind.invoice);
                          _run();
                        },
                      ),
                      ChoiceChip(
                        label: const Text('Receipt'),
                        selected: _kind == ExtractionKind.receipt,
                        onSelected: (_) {
                          setState(() => _kind = ExtractionKind.receipt);
                          _run();
                        },
                      ),
                      ChoiceChip(
                        label: const Text('Names / Dates / Amounts'),
                        selected: _kind == ExtractionKind.general,
                        onSelected: (_) {
                          setState(() => _kind = ExtractionKind.general);
                          _run();
                        },
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _loading
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
                                    OutlinedButton(onPressed: _run, child: const Text('Try Again')),
                                  ],
                                ),
                              ),
                            )
                          : (_result?.isEmpty ?? true)
                              ? Center(
                                  child: Text("No fields found for this document type.", style: TextStyle(color: secondary)),
                                )
                              : ListView(
                                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                                  children: _result!.fields.entries
                                      .map((entry) => Card(
                                            child: ListTile(
                                              title: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.w600)),
                                              subtitle: Text(entry.value),
                                            ),
                                          ))
                                      .toList(),
                                ),
                ),
              ],
            ),
    );
  }
}
