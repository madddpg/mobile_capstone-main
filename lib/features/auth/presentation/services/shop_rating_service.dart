import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:iconstruct/features/auth/presentation/models/shop_rating.dart';

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

  /// Projects where this builder selected [shopId], and so may rate it.
  ///
  /// Returns the posts newest first. An empty list means the builder has not
  /// done business with this shop and the rating action stays hidden.
  Future<List<({String postId, String title})>> ratableProjects(
    String shopId,
  ) async {
    final uid = _uid;
    if (uid == null || shopId.trim().isEmpty) return const [];

    try {
      final snap = await _db
          .collection('projectPosts')
          .where('userId', isEqualTo: uid)
          .where('selectedShopId', isEqualTo: shopId)
          .get();

      final rows = snap.docs.map((d) {
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
}
