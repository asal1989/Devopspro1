import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/router/app_router.dart';
import '../../../home/presentation/widgets/document_card.dart';
import '../../domain/entities/document.dart';
import '../providers/documents_provider.dart';
import '../widgets/document_grid_item.dart';

enum _ViewMode { grid, list }
enum _Filter { all, favorites }

/// The document library: search, sort, filter, and grid/list browsing
/// of every saved document.
class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key});

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  _ViewMode _view = _ViewMode.grid;
  _Filter _filter = _Filter.all;
  DocumentSort _sort = DocumentSort.newest;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DocumentsProvider>();
    var docs = _filter == _Filter.favorites ? provider.favorites : provider.all;
    if (_query.isNotEmpty) {
      docs = docs.where((d) => d.name.toLowerCase().contains(_query.toLowerCase())).toList();
    }
    docs = provider.sorted(docs, _sort);

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.sm),
            child: Row(
              children: [
                Text('Documents', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                const Spacer(),
                IconButton(
                  icon: Icon(_view == _ViewMode.grid ? Icons.view_list_rounded : Icons.grid_view_rounded),
                  onPressed: () => setState(() => _view = _view == _ViewMode.grid ? _ViewMode.list : _ViewMode.grid),
                ),
                PopupMenuButton<DocumentSort>(
                  icon: const Icon(Icons.sort_rounded),
                  onSelected: (v) => setState(() => _sort = v),
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: DocumentSort.newest, child: Text('Newest')),
                    PopupMenuItem(value: DocumentSort.oldest, child: Text('Oldest')),
                    PopupMenuItem(value: DocumentSort.name, child: Text('Name')),
                    PopupMenuItem(value: DocumentSort.size, child: Text('Size')),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search documents',
                prefixIcon: Icon(Icons.search_rounded),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('All'),
                  selected: _filter == _Filter.all,
                  onSelected: (_) => setState(() => _filter = _Filter.all),
                ),
                const SizedBox(width: AppSpacing.sm),
                ChoiceChip(
                  label: const Text('Favorites'),
                  avatar: const Icon(Icons.star_rounded, size: 16),
                  selected: _filter == _Filter.favorites,
                  onSelected: (_) => setState(() => _filter = _Filter.favorites),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: docs.isEmpty
                ? Center(child: Text('No documents found', style: Theme.of(context).textTheme.bodyMedium))
                : _view == _ViewMode.grid
                    ? GridView.builder(
                        padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, 100),
                        itemCount: docs.length,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: AppSpacing.sm,
                          crossAxisSpacing: AppSpacing.sm,
                          childAspectRatio: 0.78,
                        ),
                        itemBuilder: (context, index) => DocumentGridItem(
                          document: docs[index],
                          onTap: () => context.push(AppRoutes.pdfPreview, extra: docs[index]),
                          onMenuSelected: (action) => _handleMenu(context, action, docs[index]),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, 100),
                        itemCount: docs.length,
                        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                        itemBuilder: (context, index) => DocumentCard(
                          document: docs[index],
                          onTap: () => context.push(AppRoutes.pdfPreview, extra: docs[index]),
                          onMenuSelected: (action) => _handleMenu(context, action, docs[index]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  void _handleMenu(BuildContext context, String action, ScannedDocument doc) {
    final provider = context.read<DocumentsProvider>();
    switch (action) {
      case 'favorite':
        provider.toggleFavorite(doc.id);
        break;
      case 'duplicate':
        provider.duplicate(doc.id);
        break;
      case 'open':
        context.push(AppRoutes.pdfPreview, extra: doc);
        break;
      case 'delete':
        provider.delete(doc.id);
        break;
      default:
        break;
    }
  }
}
