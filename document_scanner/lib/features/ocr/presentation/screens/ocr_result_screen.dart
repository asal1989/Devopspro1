import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../documents/domain/entities/document.dart';
import '../../../documents/presentation/providers/documents_provider.dart';
import '../../data/ocr_service.dart';
import '../../domain/entities/ocr_result.dart';

/// Runs real, on-device text recognition (Google ML Kit) on a
/// document's pages and shows the result in an easy-to-read, editable
/// view. Falls back to placeholder copy for documents with no real
/// page images (e.g. Phase 1 demo documents).
class OcrResultScreen extends StatefulWidget {
  final ScannedDocument? document;
  const OcrResultScreen({super.key, this.document});

  @override
  State<OcrResultScreen> createState() => _OcrResultScreenState();
}

class _OcrResultScreenState extends State<OcrResultScreen> {
  final _ocrService = OcrService();
  OcrLanguage _language = OcrLanguage.english;
  bool _extracting = false;
  bool _editing = false;
  bool _failed = false;
  late TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.document?.extractedText ?? '');
    if (_textController.text.isEmpty) {
      _runExtraction();
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _ocrService.dispose();
    super.dispose();
  }

  Future<void> _runExtraction() async {
    setState(() {
      _extracting = true;
      _failed = false;
    });

    final imagePaths = widget.document?.pages
            .map((p) => p.originalImagePath)
            .whereType<String>()
            .toList() ??
        const [];

    try {
      String text;
      if (imagePaths.isEmpty) {
        // No real captured image to run ML Kit against (demo document) —
        // show representative placeholder copy instead of failing.
        await Future.delayed(const Duration(milliseconds: 500));
        text = 'This document has no scanned image to recognize text from. '
            'Scan a real document to see live on-device text extraction here.';
      } else {
        text = await _ocrService.recognizeDocument(imagePaths, _language);
        if (text.trim().isEmpty) {
          text = "We couldn't find any readable text on this page.";
        }
      }
      if (!mounted) return;
      setState(() {
        _extracting = false;
        _textController.text = text;
      });
      final docId = widget.document?.id;
      if (docId != null && imagePaths.isNotEmpty) {
        context.read<DocumentsProvider>().setExtractedText(docId, text);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _extracting = false;
        _failed = true;
      });
    }
  }

  void _copy() {
    Clipboard.setData(ClipboardData(text: _textController.text));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Text copied to clipboard')));
  }

  Future<void> _share() async {
    if (_textController.text.trim().isEmpty) return;
    await Share.share(_textController.text);
  }

  Future<void> _saveAsTxt() async {
    if (_textController.text.trim().isEmpty) return;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final name = (widget.document?.name ?? 'extracted-text').replaceAll(RegExp(r'[^\w\-]+'), '_');
      final file = File('${dir.path}/${name}_${DateTime.now().millisecondsSinceEpoch}.txt');
      await file.writeAsString(_textController.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Saved as ${file.uri.pathSegments.last}')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text(AppStrings.storageFailure)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final secondary = Theme.of(context).extension<AppSemanticColors>()?.textSecondary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Extract Text'),
        actions: [
          IconButton(
            icon: Icon(_editing ? Icons.check_rounded : Icons.edit_rounded),
            tooltip: 'Edit',
            onPressed: () => setState(() => _editing = !_editing),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
            child: Row(
              children: [
                Text('Language', style: TextStyle(color: secondary)),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: SizedBox(
                    height: 36,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: OcrLanguage.values.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final lang = OcrLanguage.values[index];
                        final selected = lang == _language;
                        return ChoiceChip(
                          label: Text(lang.label),
                          selected: selected,
                          onSelected: (_) {
                            setState(() => _language = lang);
                            _runExtraction();
                          },
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_language == OcrLanguage.tamil || _language == OcrLanguage.kannada)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'On-device recognition for ${_language.label} is best-effort — '
                  'full support is coming with a cloud OCR fallback.',
                  style: TextStyle(fontSize: 12, color: secondary),
                ),
              ),
            ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: _extracting
                  ? const Center(child: CircularProgressIndicator())
                  : _failed
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            child: Text(
                              AppStrings.ocrFailure,
                              textAlign: TextAlign.center,
                              style: TextStyle(color: secondary),
                            ),
                          ),
                        )
                      : SingleChildScrollView(
                          child: TextField(
                            controller: _textController,
                            readOnly: !_editing,
                            maxLines: null,
                            style: const TextStyle(height: 1.5, fontSize: 15),
                            decoration: const InputDecoration(border: InputBorder.none, isCollapsed: true),
                          ),
                        ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _extracting ? null : _runExtraction,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Extract Text'),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
            child: Row(
              children: [
                Expanded(child: _MiniAction(icon: Icons.copy_rounded, label: 'Copy', onTap: _copy)),
                Expanded(child: _MiniAction(icon: Icons.share_rounded, label: 'Share', onTap: _share)),
                Expanded(child: _MiniAction(icon: Icons.save_alt_rounded, label: 'Save TXT', onTap: _saveAsTxt)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _MiniAction({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Column(
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
