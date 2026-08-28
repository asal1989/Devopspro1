import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/services/firebase_bootstrap.dart';
import '../../domain/entities/document.dart';

/// Uploads document metadata to Firestore and the generated PDF to
/// Firebase Storage, scoped under the signed-in user's uid
/// (`users/{uid}/documents/{id}`) so one account's documents never mix
/// with another's.
///
/// **Scope note:** this is outbound (local → cloud) sync only — it
/// does not pull remote changes back down or resolve conflicts between
/// two devices editing the same document. See the README's Phase 6
/// notes for what a full two-way sync would still need.
class CloudSyncRepository {
  Future<void> uploadDocument(String uid, ScannedDocument document) async {
    if (!FirebaseBootstrap.isAvailable) {
      throw const NetworkException('Cloud sync is not set up yet.');
    }
    try {
      String? remotePdfUrl;
      final path = document.pdfPath;
      if (path != null && await File(path).exists()) {
        final ref = FirebaseStorage.instance.ref('users/$uid/documents/${document.id}.pdf');
        await ref.putFile(File(path));
        remotePdfUrl = await ref.getDownloadURL();
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('documents')
          .doc(document.id)
          .set({
        'name': document.name,
        'createdAt': document.createdAt.millisecondsSinceEpoch,
        'updatedAt': document.updatedAt.millisecondsSinceEpoch,
        'folder': document.folder,
        'isFavorite': document.isFavorite,
        'sizeInKb': document.sizeInKb,
        'category': document.category.name,
        'extractedText': document.extractedText,
        'pageCount': document.pageCount,
        'pdfUrl': remotePdfUrl,
      });
    } catch (e) {
      throw NetworkException('Upload failed for "${document.name}".', cause: e);
    }
  }

  Future<void> deleteDocument(String uid, String documentId) async {
    if (!FirebaseBootstrap.isAvailable) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).collection('documents').doc(documentId).delete();
      await FirebaseStorage.instance.ref('users/$uid/documents/$documentId.pdf').delete();
    } catch (_) {
      // Best-effort — a stray remote row/file left behind is not fatal;
      // the user can already no longer see it locally.
    }
  }
}
