import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:iconstruct/features/auth/presentation/models/ranked_shop.dart';

class ShopRankingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static List<RankedShop>? _cache;
  static DateTime? _cachedAt;
  static const Duration _ttl = Duration(minutes: 5);

  /// Storefronts already read this session, keyed by shop uid.
  static final Map<String, RankedShop> _byId = {};

  /// Clears the in-memory ranking cache (e.g. after pull-to-refresh).
  static void clearCache() {
    _cache = null;
    _byId.clear();
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
      final rankedShops = shopsQuery.docs
          .map((doc) => RankedShop.fromMap(doc.id, doc.data()))
          .toList()
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

  /// Storefronts for named shops, such as the ones that quoted an estimate.
  ///
  /// Each shop is read once per session and kept, because a comparison screen
  /// rebuilds on every quotation snapshot and the storefront does not change
  /// between them. A shop that cannot be read is left out: its quotation is
  /// still shown, just without a profile behind it.
  Future<Map<String, RankedShop>> fetchByIds(Iterable<String> shopIds) async {
    final wanted = <String>{
      for (final id in shopIds)
        if (id.trim().isNotEmpty) id.trim(),
    };

    final found = <String, RankedShop>{};
    final missing = <String>[];
    for (final id in wanted) {
      final cached = _byId[id];
      if (cached != null) {
        found[id] = cached;
      } else {
        missing.add(id);
      }
    }

    await Future.wait(missing.map((id) async {
      try {
        final snap = await _firestore.collection('shops').doc(id).get();
        if (!snap.exists) return;
        final shop = RankedShop.fromMap(snap.id, snap.data() ?? {});
        _byId[id] = shop;
        found[id] = shop;
      } catch (e) {
        debugPrint('ShopRankingService: could not read shop $id: $e');
      }
    }));

    return found;
  }
}
