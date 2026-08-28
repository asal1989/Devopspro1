import 'dart:convert';
import 'dart:ui' show Color, Offset;

import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../../../scanner/domain/entities/scan_page.dart';
import '../../domain/entities/document.dart';

enum SyncQueueStatus { pending, uploading, failed }

/// One row of the `sync_queue` table — a document waiting for (or that
/// failed) its upload to the cloud.
class SyncQueueEntry {
  final String documentId;
  final SyncQueueStatus status;
  final int retryCount;
  final String? lastError;

  const SyncQueueEntry({
    required this.documentId,
    required this.status,
    this.retryCount = 0,
    this.lastError,
  });
}

/// SQLite-backed storage for the document library — implements the
/// `documents`, `pages`, and `sync_queue` tables described in the
/// README, used by [DocumentsProvider] (local persistence) and
/// [SyncService] (the Phase 6 cloud upload queue).
///
/// Kept behind a small, explicit surface rather than exposing the
/// `Database` directly, so a future swap to a different local store
/// only touches this file.
class DocumentsDatabase {
  DocumentsDatabase._();
  static final DocumentsDatabase instance = DocumentsDatabase._();

  static const _schemaVersion = 2;

  Database? _db;

  Future<Database> get _database async {
    final existing = _db;
    if (existing != null) return existing;
    final dir = await getApplicationDocumentsDirectory();
    final db = await openDatabase(
      '${dir.path}/scanova.db',
      version: _schemaVersion,
      onCreate: (db, version) async {
        await _createV1Tables(db);
        await _createV2Additions(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) await _createV2Additions(db);
      },
    );
    _db = db;
    return db;
  }

  Future<void> _createV1Tables(Database db) async {
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
  }

  Future<void> _createV2Additions(Database db) async {
    final columns = await db.rawQuery('PRAGMA table_info(documents)');
    final existingColumns = columns.map((c) => c['name'] as String).toSet();
    if (!existingColumns.contains('updated_at')) {
      await db.execute('ALTER TABLE documents ADD COLUMN updated_at INTEGER');
      await db.execute('UPDATE documents SET updated_at = created_at WHERE updated_at IS NULL');
    }
    if (!existingColumns.contains('synced_at')) {
      await db.execute('ALTER TABLE documents ADD COLUMN synced_at INTEGER');
    }
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_queue (
        document_id TEXT PRIMARY KEY,
        status TEXT NOT NULL,
        retry_count INTEGER NOT NULL DEFAULT 0,
        last_error TEXT
      )
    ''');
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
    await db.delete('sync_queue', where: 'document_id = ?', whereArgs: [id]);
  }

  // --- Sync queue -----------------------------------------------------

  Future<void> enqueueForSync(String documentId) async {
    final db = await _database;
    await db.insert(
      'sync_queue',
      {'document_id': documentId, 'status': SyncQueueStatus.pending.name, 'retry_count': 0, 'last_error': null},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> dequeue(String documentId) async {
    final db = await _database;
    await db.delete('sync_queue', where: 'document_id = ?', whereArgs: [documentId]);
  }

  Future<List<SyncQueueEntry>> pendingSyncEntries() async {
    final db = await _database;
    final rows = await db.query('sync_queue', where: 'status != ?', whereArgs: [SyncQueueStatus.uploading.name]);
    return rows
        .map((r) => SyncQueueEntry(
              documentId: r['document_id'] as String,
              status: SyncQueueStatus.values.byName(r['status'] as String),
              retryCount: r['retry_count'] as int,
              lastError: r['last_error'] as String?,
            ))
        .toList();
  }

  Future<void> markSyncStatus(String documentId, SyncQueueStatus status, {String? error, int? retryCount}) async {
    final db = await _database;
    await db.update(
      'sync_queue',
      {
        'status': status.name,
        if (error != null) 'last_error': error,
        if (retryCount != null) 'retry_count': retryCount,
      },
      where: 'document_id = ?',
      whereArgs: [documentId],
    );
  }

  Map<String, Object?> _documentToRow(ScannedDocument doc) => {
        'id': doc.id,
        'name': doc.name,
        'created_at': doc.createdAt.millisecondsSinceEpoch,
        'updated_at': doc.updatedAt.millisecondsSinceEpoch,
        'synced_at': doc.syncedAt?.millisecondsSinceEpoch,
        'folder': doc.folder,
        'is_favorite': doc.isFavorite ? 1 : 0,
        'size_kb': doc.sizeInKb,
        'category': doc.category.name,
        'extracted_text': doc.extractedText,
        'pdf_path': doc.pdfPath,
        'thumbnail_color': doc.thumbnailColor.value,
      };

  ScannedDocument _documentFromRow(Map<String, Object?> row, List<ScanPage> pages) {
    final updatedAtMs = row['updated_at'] as int?;
    final syncedAtMs = row['synced_at'] as int?;
    return ScannedDocument(
      id: row['id'] as String,
      name: row['name'] as String,
      pages: pages,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
      updatedAt: updatedAtMs != null ? DateTime.fromMillisecondsSinceEpoch(updatedAtMs) : null,
      folder: row['folder'] as String?,
      isFavorite: (row['is_favorite'] as int) == 1,
      sizeInKb: row['size_kb'] as int,
      category: DocumentCategory.values.byName(row['category'] as String),
      extractedText: row['extracted_text'] as String?,
      thumbnailColor: Color(row['thumbnail_color'] as int),
      pdfPath: row['pdf_path'] as String?,
      syncedAt: syncedAtMs != null ? DateTime.fromMillisecondsSinceEpoch(syncedAtMs) : null,
    );
  }

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
