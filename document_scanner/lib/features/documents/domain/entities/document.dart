import 'package:flutter/material.dart';

import '../../../scanner/domain/entities/scan_page.dart';

enum DocumentCategory { general, receipt, idCard, businessCard, certificate, form, invoice }

/// A saved, multi-page scanned document.
class ScannedDocument {
  final String id;
  final String name;
  final List<ScanPage> pages;
  final DateTime createdAt;
  final String? folder;
  final bool isFavorite;
  final int sizeInKb;
  final DocumentCategory category;
  final String? extractedText;
  final Color thumbnailColor;

  const ScannedDocument({
    required this.id,
    required this.name,
    required this.pages,
    required this.createdAt,
    this.folder,
    this.isFavorite = false,
    this.sizeInKb = 0,
    this.category = DocumentCategory.general,
    this.extractedText,
    this.thumbnailColor = Colors.blueGrey,
  });

  int get pageCount => pages.length;

  ScannedDocument copyWith({
    String? name,
    List<ScanPage>? pages,
    String? folder,
    bool? isFavorite,
    int? sizeInKb,
    DocumentCategory? category,
    String? extractedText,
  }) {
    return ScannedDocument(
      id: id,
      name: name ?? this.name,
      pages: pages ?? this.pages,
      createdAt: createdAt,
      folder: folder ?? this.folder,
      isFavorite: isFavorite ?? this.isFavorite,
      sizeInKb: sizeInKb ?? this.sizeInKb,
      category: category ?? this.category,
      extractedText: extractedText ?? this.extractedText,
      thumbnailColor: thumbnailColor,
    );
  }
}
