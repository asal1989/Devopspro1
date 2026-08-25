import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../documents/domain/entities/document.dart';

/// Compact card used in "Recent Documents" and list views: thumbnail,
/// name, page count, timestamp, and a "more" menu.
class DocumentCard extends StatelessWidget {
  final ScannedDocument document;
  final VoidCallback? onTap;
  final void Function(String action)? onMenuSelected;

  const DocumentCard({super.key, required this.document, this.onTap, this.onMenuSelected});

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
          child: Row(
            children: [
              _Thumbnail(document: document),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      document.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '${document.pageCount} page${document.pageCount == 1 ? '' : 's'} · '
                      '${DateFormat('MMM d, h:mm a').format(document.createdAt)}',
                      style: theme.textTheme.bodySmall?.copyWith(color: secondary),
                    ),
                  ],
                ),
              ),
              if (document.isFavorite)
                Icon(Icons.star_rounded, color: theme.extension<AppSemanticColors>()?.warning, size: 20),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded),
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
        ),
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  final ScannedDocument document;
  const _Thumbnail({required this.document});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 56,
      decoration: BoxDecoration(
        color: document.thumbnailColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(color: document.thumbnailColor.withOpacity(0.35)),
      ),
      child: Icon(Icons.description_rounded, color: document.thumbnailColor, size: 22),
    );
  }
}
