import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:iconstruct/features/auth/presentation/models/shop_rating.dart';
import 'package:iconstruct/features/bidding/data/shop_confirmation.dart';

/// Reads and writes builder ratings of hardware shops.
///
/// One rating document per builder per shop, keyed by the builder's uid, so
/// rating a shop twice replaces the earlier score instead of stacking. The
/// average that appears on the shop card is recomputed by a Cloud Function
/// after each write, because builders have no permission to touch a shop
/// document and should not be trusted to calculate their own supplier's score.
class ShopRatingService {
  ShopRatingService({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _db = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  String? get _uid => _auth.currentUser?.uid;

  DocumentReference<Map<String, dynamic>> _ratingRef(String shopId, String uid) =>
      _db.collection('shops').doc(shopId).collection('ratings').doc(uid);

  /// This builder's own rating of a shop, if they have left one.
  Future<ShopRatingDraft?> myRating(String shopId) async {
    final uid = _uid;
    if (uid == null || shopId.trim().isEmpty) return null;
    try {
      final snap = await _ratingRef(shopId, uid).get();
      final data = snap.data();
      if (data == null) return null;
      final stars = data['stars'];
      return ShopRatingDraft(
        stars: stars is num ? stars.toInt() : 0,
        postId: (data['postId'] ?? '').toString(),
        comment: (data['comment'] ?? '').toString(),
      );
    } catch (_) {
      return null;
    }
  }

  /// Submits or replaces this builder's rating.
  ///
  /// The document carries the builder's uid and the project it came from, both
  /// of which the security rules check: only the builder who selected this shop
  /// for that project may rate it, which is what stops a shop or a rival from
  /// inflating or sinking a score.
  Future<void> submit({
    required String shopId,
    required ShopRatingDraft draft,
  }) async {
    final uid = _uid;
    if (uid == null) {
      throw StateError('You have been signed out. Please sign in again.');
    }
    if (!draft.isValid) {
      throw ArgumentError('A rating needs one to five stars and a project.');
    }

    await _ratingRef(shopId, uid).set({
      ...draft.toMap(),
      'builderId': uid,
      'shopId': shopId,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Removes this builder's rating.
  Future<void> withdraw(String shopId) async {
    final uid = _uid;
    if (uid == null) return;
    await _ratingRef(shopId, uid).delete();
  }

  /// Projects where this builder selected [shopId] and the shop confirmed the
  /// order, and so may rate it.
  ///
  /// Returns the posts newest first. An empty list means the builder has not
  /// done business with this shop and the rating action stays hidden. An
  /// order the shop has not confirmed yet, or backed out of, is not business
  /// done.
  Future<List<({String postId, String title})>> ratableProjects(
    Iterable<String> shopIds,
  ) async {
    final uid = _uid;
    final ids = shopIds.map((id) => id.trim()).where((id) => id.isNotEmpty).toSet();
    if (uid == null || ids.isEmpty) return const [];

    try {
      final snaps = await Future.wait(
        ids.map(
          (shopId) => _db
              .collection('projectPosts')
              .where('userId', isEqualTo: uid)
              .where('selectedShopId', isEqualTo: shopId)
              .get(),
        ),
      );
      final byId = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
      for (final snap in snaps) {
        for (final doc in snap.docs) {
          byId[doc.id] = doc;
        }
      }
      final snapDocs = byId.values.toList();

      final confirmed = await Future.wait(
        snapDocs.map((d) => _shopConfirmed(d.id, d.data())),
      );

      final rows = [
        for (var i = 0; i < snapDocs.length; i++)
          if (confirmed[i]) snapDocs[i],
      ].map((d) {
        final data = d.data();
        final title = (data['projectName'] ?? data['projectTitle'] ?? '')
            .toString()
            .trim();
        return (
          postId: d.id,
          title: title.isEmpty ? 'Untitled estimate' : title,
        );
      }).toList();

      return rows;
    } catch (_) {
      // A missing composite index or a rules change should hide the action,
      // not break the shop profile the builder came to read.
      return const [];
    }
  }

  /// Whether the shop confirmed the order on this post. A quotation from
  /// before shops confirmed carries no answer and counts as confirmed.
  Future<bool> _shopConfirmed(String postId, Map<String, dynamic> post) async {
    final quotationId = (post['selectedQuotationId'] ?? '').toString().trim();
    if (quotationId.isEmpty) return true;
    final snap = await _db
        .collection('projectPosts')
        .doc(postId)
        .collection('quotations')
        .doc(quotationId)
        .get();
    return shopConfirmationOf(snap.data() ?? const {}) ==
        ShopConfirmation.confirmed;
  }
}
