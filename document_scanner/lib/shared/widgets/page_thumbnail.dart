import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/constants/app_spacing.dart';
import '../../features/scanner/domain/entities/scan_page.dart';

/// Renders a [ScanPage] as a small thumbnail: the real captured image
/// (rotated to match [ScanPage.rotationDegrees]) when one exists, or a
/// flat color placeholder for mock/demo pages that have no file.
class PageThumbnail extends StatelessWidget {
  final ScanPage page;
  final double width;
  final double height;
  final BorderRadius? borderRadius;

  const PageThumbnail({
    super.key,
    required this.page,
    this.width = 44,
    this.height = 56,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(AppSpacing.radiusSm);
    final path = page.originalImagePath;

    return ClipRRect(
      borderRadius: radius,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(border: Border.all(color: Colors.black12), borderRadius: radius),
        child: RotatedBox(
          quarterTurns: (page.rotationDegrees ~/ 90) % 4,
          child: path != null
              ? Image.file(
                  File(path),
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(color: page.originalAssetColor),
                )
              : Container(color: page.originalAssetColor),
        ),
      ),
    );
  }
}
