import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:iconstruct/features/bidding/data/bid_comparison.dart';
import 'package:iconstruct/features/bidding/data/partial_acceptance.dart';
import 'package:iconstruct/features/bidding/data/quotation_accept_service.dart';
import 'package:iconstruct/features/project_creation/data/project_lifecycle.dart';

/// Re-canvassing the lines a builder did not take from their chosen shop.
///
/// Partial acceptance lets a builder take cement from one shop and leave the
/// tile. Accepting still closes the estimate to every other shop, because an
/// estimate has one supplier: chat, ratings and the security rules all rely on
/// that. So the lines left behind go out again as a new estimate of their own,
/// linked to the first, and shops quote only those.

/// Fields that carry a shop's price. A builder's estimate never holds one.
const Set<String> _priceKeys = {
  'price',
  'unitPrice',
  'subtotal',
  'lineTotal',
  'total',
  'catalogPrice',
  'estimatedTotal',
  'listPrice',
  'accepted',
};

/// The material list for re-canvassing [dropped] lines.
///
/// Each dropped line is matched by name to the builder's own entry on the
/// original estimate, so the new estimate asks for exactly what was planned,
/// in the builder's quantity and unit. A line that matches nothing, because
/// the shop renamed it, is carried with its name, quantity, unit and size.
/// Price fields are never copied.
List<Map<String, dynamic>> remainderMaterials({
  required List<Map<String, dynamic>> dropped,
  required List<dynamic> estimateMaterials,
}) {
  final byName = <String, Map<String, dynamic>>{};
  for (final raw in estimateMaterials.whereType<Map>()) {
    final entry = Map<String, dynamic>.from(raw);
    final key = normalizeMaterialName(quotedItemName(entry));
    if (key.isNotEmpty) byName.putIfAbsent(key, () => entry);
  }

  final out = <Map<String, dynamic>>[];
  final seen = <String>{};
  for (final line in dropped) {
    final name = quotedItemName(line);
    final key = normalizeMaterialName(name);
    if (key.isEmpty || !seen.add(key)) continue;

    final source = byName[key] ??
        {
          'name': name,
          'quantity': line['quantity'] ?? line['qty'] ?? 0,
          'unit': line['unit'] ?? '',
          'size': line['size'],
          'category': line['category'] ?? 'Material',
        };
    out.add({
      for (final field in source.entries)
        if (!_priceKeys.contains(field.key)) field.key: field.value,
    });
  }
  return out;
}

/// Name for the estimate that re-canvasses what was left.
String remainderProjectName(String original) {
  final base = original.trim().isEmpty ? 'Estimate' : original.trim();
  final name = '$base (remaining lines)';
  // The posting rule caps a project name at 200 characters.
  return name.length <= 200 ? name : name.substring(0, 200);
}

class RemainderCanvassService {
  RemainderCanvassService({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _db = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  /// Posts the lines the builder did not take from [quotationId] as a new
  /// estimate linked to [postId], and returns the new estimate's post id.
  ///
  /// Runs as one transaction, and a second call returns the estimate the first
  /// one created, so a double tap cannot post the same lines twice.
  Future<String> postDroppedLines({
    required String postId,
    required String quotationId,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Please sign in again.');

    final postRef = _db.collection('projectPosts').doc(postId);
    final quotationRef = postRef.collection('quotations').doc(quotationId);

    return _db.runTransaction<String>((txn) async {
      // ---- all reads first ----
      final postSnap = await txn.get(postRef);
      if (!postSnap.exists) {
        throw Exception('That estimate is no longer available.');
      }
      final post = postSnap.data() ?? <String, dynamic>{};
      if (!isPostedEstimateOwner(post, user.uid)) {
        throw Exception('This estimate is not linked to your account.');
      }

      final existing = (post['remainderPostId'] ?? '').toString().trim();
      if (existing.isNotEmpty) return existing;

      final selected = (post['selectedQuotationId'] ?? '').toString().trim();
      if (selected != quotationId) {
        throw Exception(
          'Take part of this quotation first, then canvass the rest.',
        );
      }

      final quotationSnap = await txn.get(quotationRef);
      final summary = readAcceptance(quotationSnap.data() ?? {});
      if (!summary.isPartial) {
        throw Exception(
          'Every line from this shop was taken, so there is nothing left to canvass.',
        );
      }

      final rawMaterials = post['materials'];
      final materials = remainderMaterials(
        dropped: summary.dropped,
        estimateMaterials: rawMaterials is List ? rawMaterials : const [],
      );
      if (materials.isEmpty) {
        throw Exception('The lines you did not take could not be read.');
      }

      // ---- then all writes ----
      final savedRef = _db
          .collection('users')
          .doc(user.uid)
          .collection('saved_projects')
          .doc();
      final newPostRef = _db.collection('projectPosts').doc();
      final projectName =
          remainderProjectName((post['projectName'] ?? '').toString());
      const remarks = 'Remaining lines from an earlier estimate.';

      txn.set(newPostRef, {
        'postId': newPostRef.id,
        'userId': user.uid,
        'builderId': user.uid,
        'projectId': savedRef.id,
        'projectName': projectName,
        'projectType': post['projectType'],
        'projectScope': post['projectScope'],
        'materials': materials,
        'materialsCount': materials.length,
        'totalAreaSqm': post['totalAreaSqm'],
        'budget': post['budget'],
        'status': 'open',
        'quotationCount': 0,
        'parentPostId': postId,
        'remarks': remarks,
        'postedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      txn.set(savedRef, {
        'projectName': projectName,
        'projectType': post['projectType'],
        'costLevel': post['budget'],
        'projectScope': post['projectScope'],
        'materials': materials,
        'materialsCount': materials.length,
        'totalAreaSqm': post['totalAreaSqm'],
        'status': ProjectLifecycle.waitingForQuotations,
        'postId': newPostRef.id,
        'parentPostId': postId,
        'parentProjectId': post['projectId'],
        'projectNotes': remarks,
        'postedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      txn.update(postRef, {
        'remainderPostId': newPostRef.id,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return newPostRef.id;
    });
  }
}
