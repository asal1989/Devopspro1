import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/document.dart';

/// Card used in the Documents grid view.
class DocumentGridItem extends StatelessWidget {
  final ScannedDocument document;
  final VoidCallback? onTap;
  final void Function(String action)? onMenuSelected;

  const DocumentGridItem({super.key, required this.document, this.onTap, this.onMenuSelected});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondary = theme.extension<AppSemanticColors>()?.textSecondary;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  children: [
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: document.thumbnailColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                        border: Border.all(color: document.thumbnailColor.withOpacity(0.3)),
                      ),
                      child: Center(child: Icon(Icons.description_rounded, color: document.thumbnailColor, size: 32)),
                    ),
                    if (document.isFavorite)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Icon(Icons.star_rounded, color: theme.extension<AppSemanticColors>()?.warning, size: 18),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: Text(document.name,
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                  ),
                  PopupMenuButton<String>(
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.more_vert_rounded, size: 18),
                    onSelected: onMenuSelected,
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'open', child: Text('Open')),
                      PopupMenuItem(value: 'rename', child: Text('Rename')),
                      PopupMenuItem(value: 'share', child: Text('Share')),
                      PopupMenuItem(value: 'favorite', child: Text('Favorite')),
                      PopupMenuItem(value: 'duplicate', child: Text('Duplicate')),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
                ],
              ),
              Text(
                '${document.pageCount}p · ${DateFormat('MMM d').format(document.createdAt)}',
                style: theme.textTheme.bodySmall?.copyWith(color: secondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
