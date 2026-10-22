/// The shop's answer to a builder's selection.
///
/// Accepting a quotation is the deal: chat, rating and the invoice open at
/// once, without waiting for the shop. The one answer the shop can still give
/// from the dashboard is to back out, written as `shopConfirmation: "declined"`
/// on the quotation; the builder app only reads it.
library;

enum ShopConfirmation {
  /// The deal stands. Every accepted quotation the shop has not backed out of,
  /// including one the dashboard still marks "pending".
  confirmed,

  /// The shop turned the order down. Terminal: the quotation is also marked
  /// rejected by the dashboard.
  declined,
}

/// Reads `shopConfirmation` off a quotation document.
///
/// Only "declined" changes anything. No field, "pending", "confirmed" or a
/// value this app does not know all read as confirmed, so the builder is never
/// left waiting on the shop.
ShopConfirmation shopConfirmationOf(Map<String, dynamic> quotation) {
  final raw = '${quotation['shopConfirmation'] ?? ''}'.trim().toLowerCase();
  return raw == 'declined'
      ? ShopConfirmation.declined
      : ShopConfirmation.confirmed;
}
