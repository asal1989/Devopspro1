import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/router/app_router.dart';
import '../../../documents/domain/entities/document.dart';
import '../../../documents/presentation/providers/documents_provider.dart';
import '../../../scanner/presentation/providers/scan_session_provider.dart';
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

  @override
  void dispose() {
    _titleController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _createPdf(BuildContext context) {
    final session = context.read<ScanSessionProvider>();
    if (session.isEmpty) return;

    final document = ScannedDocument(
      id: 'doc-${DateTime.now().millisecondsSinceEpoch}',
      name: _titleController.text.trim().isEmpty ? 'Untitled Document' : _titleController.text.trim(),
      pages: session.pages,
      createdAt: DateTime.now(),
      sizeInKb: session.pageCount * (_quality == PdfQuality.high ? 480 : (_quality == PdfQuality.medium ? 260 : 120)),
      thumbnailColor: const Color(0xFF2F6FED),
    );

    context.read<DocumentsProvider>().addDocument(document);
    session.reset();
    context.pushReplacement(AppRoutes.pdfPreview, extra: document);
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
          if (_passwordProtected)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Set Password'),
              ),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: ElevatedButton(
            onPressed: pageCount == 0 ? null : () => _createPdf(context),
            child: const Text('Create PDF'),
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
