class RankedShop {
  final String uid;
  final String shopName;
  final String address;
  final String barangay;
  final String city;
  final String? subscriptionPlan;
  final int quotationCount;

  RankedShop({
    required this.uid,
    required this.shopName,
    required this.address,
    required this.barangay,
    required this.city,
    this.subscriptionPlan,
    required this.quotationCount,
  });
}
