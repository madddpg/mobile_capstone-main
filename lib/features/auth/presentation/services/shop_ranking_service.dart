import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:iconstruct/core/firebase/firestore_coerce.dart';
import 'package:iconstruct/features/auth/presentation/models/ranked_shop.dart';
import 'package:iconstruct/features/auth/presentation/models/shop_rating.dart';

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
          rating: ShopRating.fromShopData(data),
          suppliedCategories: RankedShop.readList(data['suppliedCategories']),
          description: asString(data['description']),
          businessHours: asString(data['businessHours']),
          coverageCities: RankedShop.readList(data['coverageCities']),
          storefrontAbout: asString(data['storefrontAbout']),
          shopName: asString(data['shopName'], fallback: 'Unknown Shop'),
          address: asString(data['address']),
          barangay: asString(data['barangay']),
          city: asString(data['city']),
          subscriptionPlan: asStringOrNull(data['subscriptionPlan']),
          quotationCount: count,
        );
      }).toList()
        // Rated shops first, best first. A builder choosing who to canvass
        // cares what other builders thought, not how many quotes a shop has
        // fired off. Unrated shops keep their place below rather than being
        // hidden, otherwise a new shop could never earn its first rating.
        ..sort((a, b) {
          if (a.rating.hasRatings != b.rating.hasRatings) {
            return a.rating.hasRatings ? -1 : 1;
          }
          final byRating = b.rating.average.compareTo(a.rating.average);
          if (byRating != 0) return byRating;

          // Same score: more ratings is the more trustworthy one.
          final byVolume = b.rating.count.compareTo(a.rating.count);
          if (byVolume != 0) return byVolume;

          final byQuotes = b.quotationCount.compareTo(a.quotationCount);
          return byQuotes != 0
              ? byQuotes
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
