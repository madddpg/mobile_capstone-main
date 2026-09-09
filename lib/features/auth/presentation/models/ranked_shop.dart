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
}
