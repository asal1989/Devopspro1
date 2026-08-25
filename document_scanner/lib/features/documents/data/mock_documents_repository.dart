import 'package:flutter/material.dart';

import '../../scanner/domain/entities/scan_page.dart';
import '../domain/entities/document.dart';

/// Supplies realistic sample documents so Phase 1 screens have data to
/// render without a real camera/OCR/PDF pipeline wired up yet.
class MockDocumentsRepository {
  List<ScannedDocument> loadSampleDocuments() {
    final now = DateTime.now();

    ScanPage page(String id, Color color) => ScanPage(id: id, originalAssetColor: color);

    return [
      ScannedDocument(
        id: 'doc-1',
        name: 'Property Agreement',
        pages: [
          page('p1', const Color(0xFFEFEAE0)),
          page('p2', const Color(0xFFEFEAE0)),
          page('p3', const Color(0xFFEFEAE0)),
          page('p4', const Color(0xFFEFEAE0)),
          page('p5', const Color(0xFFEFEAE0)),
        ],
        createdAt: now.subtract(const Duration(hours: 2)),
        sizeInKb: 2380,
        category: DocumentCategory.form,
        isFavorite: true,
        thumbnailColor: const Color(0xFF2F6FED),
        extractedText:
            'PROPERTY AGREEMENT\n\nThis agreement is made between the parties for the '
            'transfer of property located at 12 MG Road...',
      ),
      ScannedDocument(
        id: 'doc-2',
        name: 'Electricity Bill - July',
        pages: [page('p1', const Color(0xFFEFEAE0))],
        createdAt: now.subtract(const Duration(days: 1)),
        sizeInKb: 540,
        category: DocumentCategory.receipt,
        thumbnailColor: const Color(0xFF23A26D),
      ),
      ScannedDocument(
        id: 'doc-3',
        name: 'Aadhaar Card',
        pages: [page('p1', const Color(0xFFEFEAE0)), page('p2', const Color(0xFFEFEAE0))],
        createdAt: now.subtract(const Duration(days: 2)),
        sizeInKb: 860,
        category: DocumentCategory.idCard,
        thumbnailColor: const Color(0xFFE0A429),
      ),
      ScannedDocument(
        id: 'doc-4',
        name: 'ABC Traders Invoice',
        pages: [page('p1', const Color(0xFFEFEAE0))],
        createdAt: now.subtract(const Duration(days: 3)),
        sizeInKb: 410,
        category: DocumentCategory.invoice,
        thumbnailColor: const Color(0xFFE0473E),
        extractedText: 'Vendor: ABC Traders\nInvoice: INV-2026-1024\nAmount: ₹12,500\nDate: 25 August 2026',
      ),
      ScannedDocument(
        id: 'doc-5',
        name: 'Business Card - Rahul Mehta',
        pages: [page('p1', const Color(0xFFEFEAE0))],
        createdAt: now.subtract(const Duration(days: 6)),
        sizeInKb: 190,
        category: DocumentCategory.businessCard,
        thumbnailColor: const Color(0xFF8A5CF6),
      ),
      ScannedDocument(
        id: 'doc-6',
        name: 'Degree Certificate',
        pages: [page('p1', const Color(0xFFEFEAE0))],
        createdAt: now.subtract(const Duration(days: 20)),
        sizeInKb: 1290,
        category: DocumentCategory.certificate,
        thumbnailColor: const Color(0xFF2F6FED),
      ),
    ];
  }
}
