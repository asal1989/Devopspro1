import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../documents/domain/entities/document.dart';
import '../../../documents/presentation/providers/documents_provider.dart';

/// Professional preview of the generated PDF before final save, with
/// page-level actions and quick access to OCR.
class PdfPreviewScreen extends StatelessWidget {
  final ScannedDocument? document;
  const PdfPreviewScreen({super.key, this.document});

  @override
  Widget build(BuildContext context) {
    final doc = document;
    if (doc == null) {
      return const Scaffold(body: Center(child: Text('Document not found')));
    }

    final secondary = Theme.of(context).extension<AppSemanticColors>()?.textSecondary;

    return Scaffold(
      appBar: AppBar(
        title: Text(doc.name, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: const Icon(Icons.text_snippet_rounded),
            tooltip: 'Extract Text',
            onPressed: () => context.push(AppRoutes.ocr, extra: doc),
          ),
          IconButton(
            icon: const Icon(Icons.drive_file_rename_outline_rounded),
            tooltip: 'Rename',
            onPressed: () => _rename(context, doc),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Text('${doc.pageCount} pages · ${(doc.sizeInKb / 1024).toStringAsFixed(1)} MB',
              style: TextStyle(color: secondary)),
          const SizedBox(height: AppSpacing.md),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: doc.pages.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: AppSpacing.sm,
              crossAxisSpacing: AppSpacing.sm,
              childAspectRatio: 0.72,
            ),
            itemBuilder: (context, index) {
              final page = doc.pages[index];
              return Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: page.originalAssetColor,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                      border: Border.all(color: Colors.black12),
                    ),
                  ),
                  Positioned(
                    left: 6,
                    bottom: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(6)),
                      child: Text('${index + 1}', style: const TextStyle(color: Colors.white, fontSize: 11)),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _ActionChip(icon: Icons.add_rounded, label: 'Add page', onTap: () => context.push(AppRoutes.scan)),
              _ActionChip(icon: Icons.edit_rounded, label: 'Edit page', onTap: () => context.push(AppRoutes.pages)),
              _ActionChip(icon: Icons.rotate_right_rounded, label: 'Rotate', onTap: () {}),
              _ActionChip(icon: Icons.swap_vert_rounded, label: 'Reorder', onTap: () => context.push(AppRoutes.pages)),
              _ActionChip(icon: Icons.text_snippet_rounded, label: 'OCR', onTap: () => context.push(AppRoutes.ocr, extra: doc)),
              _ActionChip(
                icon: Icons.delete_outline_rounded,
                label: 'Delete',
                onTap: () => _confirmDelete(context, doc),
              ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: ElevatedButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Document saved')));
              context.go(AppRoutes.home);
            },
            child: const Text('Save Document'),
          ),
        ),
      ),
    );
  }

  void _rename(BuildContext context, ScannedDocument doc) {
    final controller = TextEditingController(text: doc.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Document'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              context.read<DocumentsProvider>().rename(doc.id, controller.text.trim());
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, ScannedDocument doc) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete document?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              context.read<DocumentsProvider>().delete(doc.id);
              Navigator.pop(ctx);
              context.go(AppRoutes.home);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionChip({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      onPressed: onTap,
    );
  }
}
