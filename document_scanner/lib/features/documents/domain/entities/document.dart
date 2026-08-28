import 'package:flutter/material.dart';

import '../../../scanner/domain/entities/scan_page.dart';

enum DocumentCategory { general, receipt, idCard, businessCard, certificate, form, invoice }

/// A saved, multi-page scanned document.
class ScannedDocument {
  final String id;
  final String name;
  final List<ScanPage> pages;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? folder;
  final bool isFavorite;
  final int sizeInKb;
  final DocumentCategory category;
  final String? extractedText;
  final Color thumbnailColor;

  /// Path to the generated PDF file on disk, once created. Null for
  /// documents that have not been through PDF generation yet (or the
  /// Phase 1 mock samples).
  final String? pdfPath;

  /// When this version of the document was last successfully uploaded
  /// to the cloud. Null if it has never synced, or has local changes
  /// made after the last successful sync (see `SyncService` — it
  /// compares this against [updatedAt] to decide what needs uploading).
  final DateTime? syncedAt;

  ScannedDocument({
    required this.id,
    required this.name,
    required this.pages,
    required this.createdAt,
    DateTime? updatedAt,
    this.folder,
    this.isFavorite = false,
    this.sizeInKb = 0,
    this.category = DocumentCategory.general,
    this.extractedText,
    this.thumbnailColor = Colors.blueGrey,
    this.pdfPath,
    this.syncedAt,
  }) : updatedAt = updatedAt ?? createdAt;

  int get pageCount => pages.length;

  /// True once every local change has a matching successful upload.
  bool get isSynced => syncedAt != null && !syncedAt!.isBefore(updatedAt);

  ScannedDocument copyWith({
    String? name,
    List<ScanPage>? pages,
    String? folder,
    bool? isFavorite,
    int? sizeInKb,
    DocumentCategory? category,
    String? extractedText,
    String? pdfPath,
    DateTime? syncedAt,
    bool touchUpdatedAt = true,
  }) {
    return ScannedDocument(
      id: id,
      name: name ?? this.name,
      pages: pages ?? this.pages,
      createdAt: createdAt,
      updatedAt: touchUpdatedAt ? DateTime.now() : updatedAt,
      folder: folder ?? this.folder,
      isFavorite: isFavorite ?? this.isFavorite,
      sizeInKb: sizeInKb ?? this.sizeInKb,
      category: category ?? this.category,
      extractedText: extractedText ?? this.extractedText,
      thumbnailColor: thumbnailColor,
      pdfPath: pdfPath ?? this.pdfPath,
      syncedAt: syncedAt ?? this.syncedAt,
    );
  }
}
