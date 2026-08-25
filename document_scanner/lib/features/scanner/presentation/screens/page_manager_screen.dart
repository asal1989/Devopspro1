import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/router/app_router.dart';
import '../../../../shared/widgets/page_thumbnail.dart';
import '../../domain/entities/scan_page.dart';
import '../providers/scan_session_provider.dart';

/// Shows every page captured in this scan session as reorderable
/// thumbnails. Users can add another page, delete, rotate, replace, or
/// drag to reorder before continuing to PDF creation.
class PageManagerScreen extends StatelessWidget {
  const PageManagerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<ScanSessionProvider>();
    final pages = session.pages;

    return Scaffold(
      appBar: AppBar(title: const Text('Page Manager')),
      body: pages.isEmpty
          ? Center(
              child: Text('No pages yet', style: Theme.of(context).textTheme.bodyMedium),
            )
          : ReorderableGridView(
              pages: pages,
              onReorder: (oldIndex, newIndex) => context.read<ScanSessionProvider>().reorderPage(oldIndex, newIndex),
              onDelete: (index) => context.read<ScanSessionProvider>().deletePage(index),
              onRotate: (index) => context.read<ScanSessionProvider>().rotatePage(index),
              onEdit: (index) {
                context.read<ScanSessionProvider>().setActivePage(index);
                context.push(AppRoutes.enhance);
              },
              onReplace: (index) => _replacePage(context, index),
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.push(AppRoutes.scan),
                  icon: const Icon(Icons.add_a_photo_rounded),
                  label: const Text('Add Page'),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: ElevatedButton(
                  onPressed: pages.isEmpty ? null : () => context.push(AppRoutes.pdfOptions),
                  child: const Text('Done'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _replacePage(BuildContext context, int index) async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 92);
    if (file == null) return;
    if (!context.mounted) return;
    context.read<ScanSessionProvider>().replacePageWithFile(index, file.path);
  }
}

class ReorderableGridView extends StatelessWidget {
  final List<ScanPage> pages;
  final void Function(int oldIndex, int newIndex) onReorder;
  final void Function(int index) onDelete;
  final void Function(int index) onRotate;
  final void Function(int index) onEdit;
  final void Function(int index) onReplace;

  const ReorderableGridView({
    super.key,
    required this.pages,
    required this.onReorder,
    required this.onDelete,
    required this.onRotate,
    required this.onEdit,
    required this.onReplace,
  });

  @override
  Widget build(BuildContext context) {
    return ReorderableListView.builder(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: pages.length,
      onReorder: onReorder,
      itemBuilder: (context, index) {
        final page = pages[index];
        return Card(
          key: ValueKey(page.id),
          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
            leading: PageThumbnail(page: page),
            title: Text('Page ${index + 1}', style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(page.filter.label),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(icon: const Icon(Icons.edit_rounded), onPressed: () => onEdit(index)),
                IconButton(icon: const Icon(Icons.rotate_right_rounded), onPressed: () => onRotate(index)),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded),
                  onSelected: (value) {
                    if (value == 'replace') onReplace(index);
                    if (value == 'delete') onDelete(index);
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'replace', child: Text('Replace page')),
                    PopupMenuItem(value: 'delete', child: Text('Delete page')),
                  ],
                ),
                const Icon(Icons.drag_handle_rounded),
              ],
            ),
          ),
        );
      },
    );
  }
}
