import 'dart:convert';
import 'dart:ui' show Color, Offset;

import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../../../scanner/domain/entities/scan_page.dart';
import '../../domain/entities/document.dart';

/// SQLite-backed storage for the document library — implements the
/// schema described in the README (`documents` + `pages` tables), used
/// by [DocumentsProvider] so the library survives an app restart.
///
/// Kept behind a small, explicit surface (`loadAll` / `upsert` /
/// `delete`) rather than exposing the `Database` directly, so a future
/// swap to a different local store only touches this file.
class DocumentsDatabase {
  DocumentsDatabase._();
  static final DocumentsDatabase instance = DocumentsDatabase._();

  Database? _db;

  Future<Database> get _database async {
    final existing = _db;
    if (existing != null) return existing;
    final dir = await getApplicationDocumentsDirectory();
    final db = await openDatabase(
      '${dir.path}/scanova.db',
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE documents (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            folder TEXT,
            is_favorite INTEGER NOT NULL DEFAULT 0,
            size_kb INTEGER NOT NULL DEFAULT 0,
            category TEXT NOT NULL,
            extracted_text TEXT,
            pdf_path TEXT,
            thumbnail_color INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE pages (
            id TEXT PRIMARY KEY,
            document_id TEXT NOT NULL,
            position INTEGER NOT NULL,
            original_image_path TEXT,
            original_color INTEGER NOT NULL,
            crop_corners TEXT,
            rotation_degrees INTEGER NOT NULL DEFAULT 0,
            filter TEXT NOT NULL,
            brightness REAL NOT NULL DEFAULT 0,
            contrast REAL NOT NULL DEFAULT 0,
            sharpness REAL NOT NULL DEFAULT 0,
            FOREIGN KEY (document_id) REFERENCES documents(id) ON DELETE CASCADE
          )
        ''');
        await db.execute('CREATE INDEX idx_pages_document_id ON pages(document_id)');
      },
    );
    _db = db;
    return db;
  }

  Future<List<ScannedDocument>> loadAll() async {
    final db = await _database;
    final documentRows = await db.query('documents', orderBy: 'created_at DESC');
    final result = <ScannedDocument>[];
    for (final row in documentRows) {
      final pageRows = await db.query(
        'pages',
        where: 'document_id = ?',
        whereArgs: [row['id']],
        orderBy: 'position ASC',
      );
      result.add(_documentFromRow(row, pageRows.map(_pageFromRow).toList()));
    }
    return result;
  }

  /// Inserts or fully replaces a document and its pages in one
  /// transaction — simplest way to keep page order/content correct
  /// without diffing, and document counts stay small enough that this
  /// is cheap.
  Future<void> upsert(ScannedDocument document) async {
    final db = await _database;
    await db.transaction((txn) async {
      await txn.insert('documents', _documentToRow(document), conflictAlgorithm: ConflictAlgorithm.replace);
      await txn.delete('pages', where: 'document_id = ?', whereArgs: [document.id]);
      for (var i = 0; i < document.pages.length; i++) {
        await txn.insert('pages', _pageToRow(document.pages[i], document.id, i));
      }
    });
  }

  Future<void> delete(String id) async {
    final db = await _database;
    await db.delete('pages', where: 'document_id = ?', whereArgs: [id]);
    await db.delete('documents', where: 'id = ?', whereArgs: [id]);
  }

  Map<String, Object?> _documentToRow(ScannedDocument doc) => {
        'id': doc.id,
        'name': doc.name,
        'created_at': doc.createdAt.millisecondsSinceEpoch,
        'folder': doc.folder,
        'is_favorite': doc.isFavorite ? 1 : 0,
        'size_kb': doc.sizeInKb,
        'category': doc.category.name,
        'extracted_text': doc.extractedText,
        'pdf_path': doc.pdfPath,
        'thumbnail_color': doc.thumbnailColor.value,
      };

  ScannedDocument _documentFromRow(Map<String, Object?> row, List<ScanPage> pages) => ScannedDocument(
        id: row['id'] as String,
        name: row['name'] as String,
        pages: pages,
        createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
        folder: row['folder'] as String?,
        isFavorite: (row['is_favorite'] as int) == 1,
        sizeInKb: row['size_kb'] as int,
        category: DocumentCategory.values.byName(row['category'] as String),
        extractedText: row['extracted_text'] as String?,
        thumbnailColor: Color(row['thumbnail_color'] as int),
        pdfPath: row['pdf_path'] as String?,
      );

  Map<String, Object?> _pageToRow(ScanPage page, String documentId, int position) => {
        'id': page.id,
        'document_id': documentId,
        'position': position,
        'original_image_path': page.originalImagePath,
        'original_color': page.originalAssetColor.value,
        'crop_corners':
            page.cropCorners == null ? null : jsonEncode(page.cropCorners!.map((o) => [o.dx, o.dy]).toList()),
        'rotation_degrees': page.rotationDegrees,
        'filter': page.filter.name,
        'brightness': page.brightness,
        'contrast': page.contrast,
        'sharpness': page.sharpness,
      };

  ScanPage _pageFromRow(Map<String, Object?> row) {
    List<Offset>? corners;
    final raw = row['crop_corners'] as String?;
    if (raw != null) {
      final decoded = jsonDecode(raw) as List<dynamic>;
      corners = decoded
          .map((e) => Offset((e[0] as num).toDouble(), (e[1] as num).toDouble()))
          .toList();
    }
    return ScanPage(
      id: row['id'] as String,
      originalImagePath: row['original_image_path'] as String?,
      originalAssetColor: Color(row['original_color'] as int),
      cropCorners: corners,
      rotationDegrees: row['rotation_degrees'] as int,
      filter: PageFilter.values.byName(row['filter'] as String),
      brightness: (row['brightness'] as num).toDouble(),
      contrast: (row['contrast'] as num).toDouble(),
      sharpness: (row['sharpness'] as num).toDouble(),
    );
  }
}
