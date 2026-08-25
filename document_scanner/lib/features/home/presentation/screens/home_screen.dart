import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../documents/presentation/providers/documents_provider.dart';
import '../widgets/document_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondary = theme.extension<AppSemanticColors>()?.textSecondary;
    final documents = context.watch<DocumentsProvider>();
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? 'Good morning' : (hour < 17 ? 'Good afternoon' : 'Good evening');

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 120),
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: const Icon(Icons.document_scanner_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(AppStrings.appName, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                    Text(greeting, style: theme.textTheme.bodySmall?.copyWith(color: secondary)),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => _openSearch(context),
                icon: const Icon(Icons.search_rounded),
              ),
              IconButton(
                onPressed: () => context.push(AppRoutes.settings),
                icon: const Icon(Icons.settings_rounded),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          _ScanCta(onTap: () => context.push(AppRoutes.scan)),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _SecondaryAction(
                  icon: Icons.photo_library_rounded,
                  label: 'Import from\nGallery',
                  onTap: () => context.push(AppRoutes.crop),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _SecondaryAction(
                  icon: Icons.badge_rounded,
                  label: 'Scan ID\nCard',
                  onTap: () => context.push(AppRoutes.scan),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _SecondaryAction(
                  icon: Icons.qr_code_scanner_rounded,
                  label: 'Scan QR /\nBarcode',
                  onTap: () => context.push(AppRoutes.scan),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Recent Documents', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              TextButton(onPressed: () {}, child: const Text('See all')),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (documents.recent.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
              child: Center(
                child: Text('No documents yet. Tap "Scan Document" to get started.',
                    style: theme.textTheme.bodyMedium?.copyWith(color: secondary)),
              ),
            )
          else
            ...documents.recent.map(
              (doc) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: DocumentCard(
                  document: doc,
                  onTap: () => context.push(AppRoutes.pdfPreview, extra: doc),
                  onMenuSelected: (action) => _handleMenu(context, action, doc.id),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _handleMenu(BuildContext context, String action, String docId) {
    final provider = context.read<DocumentsProvider>();
    switch (action) {
      case 'favorite':
        provider.toggleFavorite(docId);
        break;
      case 'duplicate':
        provider.duplicate(docId);
        break;
      case 'delete':
        _confirmDelete(context, provider, docId);
        break;
      default:
        break;
    }
  }

  void _confirmDelete(BuildContext context, DocumentsProvider provider, String docId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete document?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              provider.delete(docId);
              Navigator.pop(ctx);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _openSearch(BuildContext context) {
    showSearch(context: context, delegate: _DocumentSearchDelegate());
  }
}

class _DocumentSearchDelegate extends SearchDelegate<void> {
  @override
  List<Widget>? buildActions(BuildContext context) => [IconButton(onPressed: () => query = '', icon: const Icon(Icons.clear))];

  @override
  Widget buildLeading(BuildContext context) =>
      IconButton(onPressed: () => close(context, null), icon: const Icon(Icons.arrow_back));

  @override
  Widget buildResults(BuildContext context) => _buildList(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildList(context);

  Widget _buildList(BuildContext context) {
    final results = context.read<DocumentsProvider>().search(query);
    if (results.isEmpty) {
      return const Center(child: Text('No documents found'));
    }
    return ListView(
      children: results
          .map((doc) => DocumentCard(document: doc, onTap: () => close(context, null)))
          .toList(),
    );
  }
}

class _ScanCta extends StatelessWidget {
  final VoidCallback onTap;
  const _ScanCta({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.primary,
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg, horizontal: AppSpacing.lg),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.document_scanner_rounded, color: Colors.white, size: 28),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Scan Document',
                        style: theme.textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text('Capture, enhance & save in seconds',
                        style: theme.textTheme.bodySmall?.copyWith(color: Colors.white.withOpacity(0.85))),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _SecondaryAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SecondaryAction({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md, horizontal: AppSpacing.sm),
          child: Column(
            children: [
              Icon(icon, color: theme.colorScheme.primary, size: 26),
              const SizedBox(height: AppSpacing.sm),
              Text(label, textAlign: TextAlign.center, style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}
