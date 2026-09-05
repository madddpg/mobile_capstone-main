import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:iconstruct/core/firebase/firestore_coerce.dart';
import 'package:iconstruct/features/auth/presentation/models/ranked_shop.dart';

class ShopRankingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static List<RankedShop>? _cache;
  static DateTime? _cachedAt;
  static const Duration _ttl = Duration(minutes: 5);

  /// Clears the in-memory ranking cache (e.g. after pull-to-refresh).
  static void clearCache() {
    _cache = null;
    _cachedAt = null;
  }

  Future<List<RankedShop>> fetchRankedShops({bool forceRefresh = false}) async {
    final now = DateTime.now();
    if (!forceRefresh &&
        _cache != null &&
        _cachedAt != null &&
        now.difference(_cachedAt!) < _ttl) {
      return _cache!;
    }

    try {
      // Approved + active shops. Firestore rules let any signed-in user read a
      // shop doc whose status is "approved".
      final shopsQuery = await _firestore
          .collection('shops')
          .where('status', isEqualTo: 'approved')
          .where('subscriptionStatus', isEqualTo: 'active')
          .get();

      debugPrint('ShopRankingService: Fetched ${shopsQuery.docs.length} shops');

      // Rank by a denormalized count on the shop doc itself. A builder cannot
      // read other shops' `quotations` subcollections (rules deny it), so the
      // previous unbounded `collectionGroup('quotations')` scan always failed
      // and silently returned an empty list. The web dashboard is expected to
      // maintain one of these counters on the shop doc; absent that, shops sort
      // by name so the list is at least stable and populated.
      final rankedShops = shopsQuery.docs.map((doc) {
        final data = doc.data();
        final uid = asString(data['uid'], fallback: doc.id);
        final count = asInt(firstOf(data, const [
          'quotationCount',
          'quotationsCount',
          'totalQuotations',
          'completedQuotations',
          'quotesSubmitted',
        ]));

        return RankedShop(
          uid: uid,
          shopName: asString(data['shopName'], fallback: 'Unknown Shop'),
          address: asString(data['address']),
          barangay: asString(data['barangay']),
          city: asString(data['city']),
          subscriptionPlan: asStringOrNull(data['subscriptionPlan']),
          quotationCount: count,
        );
      }).toList()
        ..sort((a, b) {
          final byCount = b.quotationCount.compareTo(a.quotationCount);
          return byCount != 0
              ? byCount
              : a.shopName.toLowerCase().compareTo(b.shopName.toLowerCase());
        });

      _cache = rankedShops;
      _cachedAt = now;
      return rankedShops;
    } catch (e) {
      debugPrint('ShopRankingService Error: $e');
      // Surface the failure instead of masking it as "no shops" — but keep a
      // usable list if we have one cached.
      if (_cache != null) return _cache!;
      rethrow;
    }
  }
}
