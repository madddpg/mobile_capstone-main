import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:iconstruct/features/bidding/data/partial_acceptance.dart';
import 'package:iconstruct/features/chat/data/chat_service.dart';
import 'package:iconstruct/features/project_creation/data/project_lifecycle.dart';

/// Firestore field names that may hold the builder's Auth uid on a post.
///
/// Security rules treat **`userId`** as the canonical owner id. Older or
/// web-side docs may use the aliases instead.
const postedEstimateOwnerKeys = [
  'userId',
  'builderId',
  'ownerId',
  'postedBy',
];

/// First non-empty owner id on a `projectPosts` document (`userId` first).
String? postedEstimateOwnerId(Map<String, dynamic> data) {
  for (final key in postedEstimateOwnerKeys) {
    final value = data[key]?.toString().trim() ?? '';
    if (value.isNotEmpty) return value;
  }
  return null;
}

bool isPostedEstimateOwner(Map<String, dynamic> data, String uid) {
  return postedEstimateOwnerKeys.any(
    (key) => data[key]?.toString() == uid,
  );
}

String quotationShopId(Map<String, dynamic> data, String documentId) {
  final fromField = data['shopId']?.toString().trim() ?? '';
  if (fromField.isNotEmpty) return fromField;
  return documentId.trim();
}

/// Marks a quotation accepted and opens the chat thread.
///
/// A Cloud Function used to create the conversation on acceptance. It was
/// deleted, so the client now always creates it through
/// [ChatService.waitOrEnsureConversation], which was written as the fallback
/// for that function and is now the only path.
class QuotationAcceptService {
  QuotationAcceptService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    ChatService? chat,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _chat = chat ?? ChatService();

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  final ChatService _chat;

  /// Accepts a shop's quotation, whole or in part.
  ///
  /// [acceptedIndexes] names the line positions the builder kept. Passing null
  /// accepts everything, which is the behaviour from before per-line choice
  /// existed, so existing callers are unaffected.
  Future<String> acceptQuotation({
    required String postId,
    required String quotationId,
    required String shopId,
    required String shopName,
    Set<int>? acceptedIndexes,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not signed in');

    final projectRef = _db.collection('projectPosts').doc(postId);
    final quotationRef = projectRef.collection('quotations').doc(quotationId);

    // Sibling quotations are read outside the transaction (Firestore forbids
    // queries inside runTransaction). Cap the reject fan-out so the transaction
    // stays well under the 500-write limit; anything beyond is reconciled
    // server-side.
    final siblings = await projectRef.collection('quotations').get();
    final toReject = siblings.docs
        .where((d) => d.id != quotationId)
        .where((d) {
          final st = (d.data()['status'] ?? '').toString().toLowerCase();
          return st != 'accepted' && st != 'rejected';
        })
        .take(400)
        .toList();

    return _db.runTransaction<String>((txn) async {
      // ---- all reads first ----
      final projectSnap = await txn.get(projectRef);
      if (!projectSnap.exists) {
        throw Exception('Posted estimate not found');
      }
      final projectData = projectSnap.data() ?? <String, dynamic>{};
      if (!isPostedEstimateOwner(projectData, user.uid)) {
        throw Exception(
          'This estimate is not linked to your account. '
          'The post must store your Auth uid in userId.',
        );
      }

      final existing =
          (projectData['selectedQuotationId'] ?? '').toString().trim();
      if (existing.isNotEmpty && existing != quotationId) {
        throw Exception('You already accepted an offer for this estimate.');
      }

      final quotationSnap = await txn.get(quotationRef);
      if (!quotationSnap.exists) {
        throw Exception('That quotation is no longer available.');
      }
      final resolvedShopId =
          quotationShopId(quotationSnap.data() ?? <String, dynamic>{}, shopId);
      if (resolvedShopId.isEmpty) {
        throw Exception('This quotation is missing a shop id.');
      }

      final savedProjectId =
          (projectData['projectId'] ?? '').toString().trim();
      DocumentReference<Map<String, dynamic>>? savedProjectRef;
      var savedProjectExists = false;
      if (savedProjectId.isNotEmpty) {
        savedProjectRef = _db
            .collection('users')
            .doc(user.uid)
            .collection('saved_projects')
            .doc(savedProjectId);
        savedProjectExists = (await txn.get(savedProjectRef)).exists;
      }

      // Resolve which lines the builder kept. The items array is rewritten
      // whole because Firestore cannot address one element of an array.
      final quotationData = quotationSnap.data() ?? <String, dynamic>{};
      final lines = quotationItems(quotationData);
      final outcome = resolveAcceptance(
        items: lines,
        acceptedIndexes: lines.isEmpty ? null : acceptedIndexes,
      );

      // ---- then all writes ----
      txn.update(quotationRef, {
        'status': outcome.status,
        'acceptedAt': FieldValue.serverTimestamp(),
        if (lines.isNotEmpty) ...{
          'items': outcome.items,
          'acceptedTotal': outcome.acceptedTotal,
        },
      });
      for (final doc in toReject) {
        txn.update(doc.reference, {
          'status': 'rejected',
          'acceptedAt': FieldValue.serverTimestamp(),
        });
      }
      txn.update(projectRef, {
        'selectedQuotationId': quotationId,
        'selectedShopId': resolvedShopId,
        'selectedShopName': shopName,
        'status': 'offer_accepted',
        'acceptedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      // Only touch the saved project if it still exists — a merge-set would
      // otherwise resurrect a deleted draft as a ghost "Unknown Project".
      if (savedProjectRef != null && savedProjectExists) {
        txn.update(savedProjectRef, {
          'status': ProjectLifecycle.supplierSelected,
          'selectedShopName': shopName,
          'supplierSelectedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      return resolvedShopId;
    });
  }

  Future<String> acceptAndOpenChat({
    required String postId,
    required String quotationId,
    required String shopId,
    required String shopName,
    Set<int>? acceptedIndexes,
    required String projectTitle,
    String builderName = 'Builder',
  }) async {
    final resolvedShopId = await acceptQuotation(
      postId: postId,
      quotationId: quotationId,
      shopId: shopId,
      shopName: shopName,
      acceptedIndexes: acceptedIndexes,
    );

    return _chat.waitOrEnsureConversation(
      projectId: postId,
      shopId: resolvedShopId,
      quotationId: quotationId,
      projectTitle: projectTitle,
      shopName: shopName,
      builderName: builderName,
    );
  }
}
