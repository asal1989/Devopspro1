import 'dart:io';

import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/router/app_router.dart';
import '../../../documents/domain/entities/document.dart';
import '../../../documents/presentation/providers/documents_provider.dart';
import '../../../scanner/presentation/providers/scan_session_provider.dart';
import '../../../settings/presentation/providers/settings_provider.dart';
import '../../data/pdf_generator.dart';
import '../../domain/entities/pdf_options.dart';

/// Collects document title, page format, quality, compression, and
/// optional password protection, then generates the PDF and saves it.
class PdfCreateOptionsScreen extends StatefulWidget {
  const PdfCreateOptionsScreen({super.key});

  @override
  State<PdfCreateOptionsScreen> createState() => _PdfCreateOptionsScreenState();
}

class _PdfCreateOptionsScreenState extends State<PdfCreateOptionsScreen> {
  final _titleController = TextEditingController(text: 'Scanned Document');
  PdfPageFormat _format = PdfPageFormat.a4;
  PdfQuality _quality = PdfQuality.high;
  bool _compress = false;
  bool _passwordProtected = false;
  final _passwordController = TextEditingController();
  bool _generating = false;

  @override
  void initState() {
    super.initState();
    final editingId = context.read<ScanSessionProvider>().editingDocumentId;
    if (editingId != null) {
      for (final doc in context.read<DocumentsProvider>().all) {
        if (doc.id == editingId) {
          _titleController.text = doc.name;
          break;
        }
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  int get _jpegQuality {
    var quality = switch (_quality) {
      PdfQuality.high => 90,
      PdfQuality.medium => 75,
      PdfQuality.low => 50,
    };
    if (_compress) quality = (quality - 20).clamp(20, 100);
    return quality;
  }

  Future<void> _createPdf(BuildContext context) async {
    final session = context.read<ScanSessionProvider>();
    if (session.isEmpty || _generating) return;

    setState(() => _generating = true);

    final pages = session.pages;
    final jobs = pages
        .map((page) => PdfPageJob(
              imagePath: page.originalImagePath,
              fallbackColor: page.originalAssetColor,
              cropCorners: page.cropCorners,
              rotationDegrees: page.rotationDegrees,
              filter: page.filter,
              brightness: page.brightness,
              contrast: page.contrast,
              sharpness: page.sharpness,
            ))
        .toList();

    try {
      final bytes = await compute(
        generatePdfInIsolate,
        GeneratePdfRequest(pages: jobs, format: _format, jpegQuality: _jpegQuality),
      );

      final docsDir = await getApplicationDocumentsDirectory();
      final fileName = 'scan_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File('${docsDir.path}/$fileName');
      await file.writeAsBytes(bytes, flush: true);

      if (!context.mounted) return;

      final settings = context.read<SettingsProvider>();
      if (!settings.saveOriginalImage) {
        for (final page in pages) {
          final path = page.originalImagePath;
          if (path == null) continue;
          try {
            final original = File(path);
            if (await original.exists()) await original.delete();
          } catch (_) {
            // Best-effort cleanup only — a stray temp file is never fatal.
          }
        }
      }

      final documentsProvider = context.read<DocumentsProvider>();
      final editingId = session.editingDocumentId;
      ScannedDocument? existing;
      if (editingId != null) {
        for (final d in documentsProvider.all) {
          if (d.id == editingId) existing = d;
        }
      }

      final enteredName = _titleController.text.trim();
      final document = existing != null
          ? existing.copyWith(
              name: enteredName.isEmpty ? existing.name : enteredName,
              pages: pages,
              sizeInKb: (bytes.length / 1024).ceil(),
              pdfPath: file.path,
            )
          : ScannedDocument(
              id: 'doc-${DateTime.now().millisecondsSinceEpoch}',
              name: enteredName.isEmpty ? 'Untitled Document' : enteredName,
              pages: pages,
              createdAt: DateTime.now(),
              sizeInKb: (bytes.length / 1024).ceil(),
              thumbnailColor: const Color(0xFF2F6FED),
              pdfPath: file.path,
            );

      if (!context.mounted) return;
      documentsProvider.updateDocument(document);
      session.reset();
      context.pushReplacement(AppRoutes.pdfPreview, extra: document);
    } catch (e) {
      if (!mounted) return;
      setState(() => _generating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("We couldn't create the PDF. Please try again.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final pageCount = context.watch<ScanSessionProvider>().pageCount;

    return Scaffold(
      appBar: AppBar(title: const Text('Create PDF')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(labelText: 'Document Name'),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(child: _InfoTile(label: 'Pages', value: '$pageCount')),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: _InfoTile(label: 'Format', value: 'PDF')),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Page Size', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              ChoiceChip(label: const Text('A4'), selected: _format == PdfPageFormat.a4, onSelected: (_) => setState(() => _format = PdfPageFormat.a4)),
              ChoiceChip(label: const Text('Letter'), selected: _format == PdfPageFormat.letter, onSelected: (_) => setState(() => _format = PdfPageFormat.letter)),
              ChoiceChip(label: const Text('Original size'), selected: _format == PdfPageFormat.original, onSelected: (_) => setState(() => _format = PdfPageFormat.original)),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Quality', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              ChoiceChip(label: const Text('High'), selected: _quality == PdfQuality.high, onSelected: (_) => setState(() => _quality = PdfQuality.high)),
              ChoiceChip(label: const Text('Medium'), selected: _quality == PdfQuality.medium, onSelected: (_) => setState(() => _quality = PdfQuality.medium)),
              ChoiceChip(label: const Text('Low'), selected: _quality == PdfQuality.low, onSelected: (_) => setState(() => _quality = PdfQuality.low)),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Compress PDF'),
            subtitle: const Text('Reduce file size for sharing'),
            value: _compress,
            onChanged: (v) => setState(() => _compress = v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Password Protection'),
            subtitle: const Text('Require a password to open this PDF'),
            value: _passwordProtected,
            onChanged: (v) => setState(() => _passwordProtected = v),
          ),
          if (_passwordProtected) ...[
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Set Password'),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(top: AppSpacing.xs),
              child: Text(
                'PDF encryption is not wired up yet — this password is saved with the '
                'document but does not yet lock the file.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: ElevatedButton(
            onPressed: (pageCount == 0 || _generating) ? null : () => _createPdf(context),
            child: _generating
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                  )
                : const Text('Create PDF'),
          ),
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String label;
  final String value;
  const _InfoTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 4),
            Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}
