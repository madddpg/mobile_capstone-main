import 'package:iconstruct/core/firebase/firestore_coerce.dart';
import 'package:iconstruct/features/auth/presentation/models/shop_rating.dart';

/// A hardware shop as the builder sees it.
///
/// The storefront fields below are written by the shop's web dashboard. The
/// builder app only reads them: shops describe themselves, the app never
/// edits a shop profile.
class RankedShop {
  final String uid;
  final String shopName;
  final String address;
  final String barangay;
  final String city;
  final String? subscriptionPlan;
  final int quotationCount;

  /// Category keys the shop says it supplies, e.g. tiles, cement, roofing.
  final List<String> suppliedCategories;

  /// Short storefront blurb.
  final String description;

  /// Free text, e.g. "Mon-Sat, 7 AM - 6 PM".
  final String businessHours;

  /// Towns the shop delivers to or serves.
  final List<String> coverageCities;

  /// Longer About text, shown on Pro and Business plans.
  final String storefrontAbout;

  /// Contact number the shop published. Empty when they left it out.
  final String phone;

  /// Builder rating, aggregated server-side onto the shop document.
  final ShopRating rating;

  RankedShop({
    required this.uid,
    required this.shopName,
    required this.address,
    required this.barangay,
    required this.city,
    this.subscriptionPlan,
    required this.quotationCount,
    this.suppliedCategories = const [],
    this.description = '',
    this.businessHours = '',
    this.coverageCities = const [],
    this.storefrontAbout = '',
    this.phone = '',
    this.rating = ShopRating.none,
  });

  /// Whether there is enough here to be worth opening a profile for.
  bool get hasStorefront =>
      description.isNotEmpty ||
      businessHours.isNotEmpty ||
      storefrontAbout.isNotEmpty ||
      suppliedCategories.isNotEmpty ||
      coverageCities.isNotEmpty;

  /// Reads a list field that may arrive as a list or as a comma-separated
  /// string, since the dashboard and older records disagree.
  static List<String> readList(Object? raw) {
    if (raw is List) {
      return raw
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    if (raw is String && raw.trim().isNotEmpty) {
      return raw
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return const [];
  }

  /// Reads a `shops/{uid}` document.
  ///
  /// One parser for both paths that need a storefront: the ranked list on the
  /// home screen, and the shops that quoted an estimate.
  factory RankedShop.fromMap(String documentId, Map<String, dynamic> data) {
    return RankedShop(
      uid: asString(data['uid'], fallback: documentId),
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
      phone: asString(data['phone']),
      subscriptionPlan: asStringOrNull(data['subscriptionPlan']),
      quotationCount: asInt(firstOf(data, const [
        'quotationCount',
        'quotationsCount',
        'totalQuotations',
        'completedQuotations',
        'quotesSubmitted',
      ])),
    );
  }

  /// Where the shop is, as one line.
  String get locationLabel =>
      [address, barangay, city].where((s) => s.trim().isNotEmpty).join(', ');

  /// The area a card can show: the town it serves, else where it is.
  String get shortLocation {
    if (city.trim().isNotEmpty) return city.trim();
    if (coverageCities.isNotEmpty) return coverageCities.first;
    if (barangay.trim().isNotEmpty) return barangay.trim();
    return address.trim();
  }

  /// "Pro" or "Business". Basic is the default plan and is not worth a badge.
  String get planLabel {
    final value = (subscriptionPlan ?? '').trim().toLowerCase();
    if (value.isEmpty || value == 'basic') return '';
    return '${value[0].toUpperCase()}${value.substring(1)}';
  }
}
