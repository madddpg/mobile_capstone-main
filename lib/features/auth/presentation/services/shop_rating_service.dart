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

  DocumentReference<Map<String, dynamic>> _ratingRef(
    String shopId,
    String uid,
  ) => _db.collection('shops').doc(shopId).collection('ratings').doc(uid);

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

  /// Projects where this builder selected [shopIds] (or [shopName]) and the order
  /// was not declined, making it eligible to rate.
  ///
  /// Returns the posts newest first. An empty list means the builder has not
  /// done business with this shop yet.
  Future<List<({String postId, String title})>> ratableProjects(
    Iterable<String> shopIds, {
    String? shopName,
  }) async {
    final uid = _uid;
    final ids = shopIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet();
    if (uid == null) return const [];

    final normalizedShopName = (shopName ?? '').trim().toLowerCase();

    try {
      final snapDocsMap = <String, Map<String, dynamic>>{};

      // 1. Fetch user's posts via single-field queries (never requires composite index)
      final userPostsSnap = await _db
          .collection('projectPosts')
          .where('userId', isEqualTo: uid)
          .get();
      for (final doc in userPostsSnap.docs) {
        snapDocsMap[doc.id] = doc.data();
      }

      // Also check builderId in case post used builderId instead of userId
      try {
        final builderPostsSnap = await _db
            .collection('projectPosts')
            .where('builderId', isEqualTo: uid)
            .get();
        for (final doc in builderPostsSnap.docs) {
          snapDocsMap[doc.id] = doc.data();
        }
      } catch (_) {}

      final eligibleDocs = <String, Map<String, dynamic>>{};

      for (final entry in snapDocsMap.entries) {
        final data = entry.value;
        final selectedId = (data['selectedShopId'] ?? '').toString().trim();
        final selectedName = (data['selectedShopName'] ?? '').toString().trim().toLowerCase();

        final matchesId = ids.isNotEmpty && ids.contains(selectedId);
        final matchesName = normalizedShopName.isNotEmpty &&
            selectedName.isNotEmpty &&
            (selectedName == normalizedShopName ||
                selectedName.contains(normalizedShopName) ||
                normalizedShopName.contains(selectedName));

        if (matchesId || matchesName) {
          eligibleDocs[entry.key] = data;
        }
      }

      // 2. Also inspect saved_projects if projectPosts didn't find any direct matches
      if (eligibleDocs.isEmpty) {
        try {
          final savedSnap = await _db
              .collection('users')
              .doc(uid)
              .collection('saved_projects')
              .get();
          for (final doc in savedSnap.docs) {
            final data = doc.data();
            final savedPostId = (data['postId'] ?? '').toString().trim();
            final savedShopId = (data['selectedShopId'] ?? '').toString().trim();
            final savedShopName = (data['selectedShopName'] ?? '').toString().trim().toLowerCase();

            final matchesId = ids.isNotEmpty && ids.contains(savedShopId);
            final matchesName = normalizedShopName.isNotEmpty &&
                savedShopName.isNotEmpty &&
                (savedShopName == normalizedShopName ||
                    savedShopName.contains(normalizedShopName) ||
                    normalizedShopName.contains(savedShopName));

            if ((matchesId || matchesName) && savedPostId.isNotEmpty) {
              if (snapDocsMap.containsKey(savedPostId)) {
                eligibleDocs[savedPostId] = snapDocsMap[savedPostId]!;
              } else {
                eligibleDocs[savedPostId] = {
                  'projectName': data['name'] ?? data['projectName'] ?? 'Saved Estimate',
                  'selectedShopId': savedShopId,
                };
              }
            }
          }
        } catch (_) {}
      }

      // 3. Exclude only orders that were explicitly declined
      final rows = <({String postId, String title})>[];
      for (final entry in eligibleDocs.entries) {
        final postId = entry.key;
        final data = entry.value;

        final isDeclined = await _isOrderDeclined(postId, data);
        if (!isDeclined) {
          final title = (data['projectName'] ?? data['projectTitle'] ?? '')
              .toString()
              .trim();
          rows.add((
            postId: postId,
            title: title.isEmpty ? 'Untitled estimate' : title,
          ));
        }
      }

      return rows;
    } catch (_) {
      return const [];
    }
  }

  /// Only blocks rating if the shop explicitly backed out / declined the order.
  /// If pending or confirmed, rating is allowed once supplier is chosen.
  Future<bool> _isOrderDeclined(String postId, Map<String, dynamic> post) async {
    final quotationId = (post['selectedQuotationId'] ?? '').toString().trim();
    if (quotationId.isEmpty) return false;
    try {
      final snap = await _db
          .collection('projectPosts')
          .doc(postId)
          .collection('quotations')
          .doc(quotationId)
          .get();
      final data = snap.data() ?? const {};
      return shopConfirmationOf(data) == ShopConfirmation.declined;
    } catch (_) {
      return false;
    }
  }
}
