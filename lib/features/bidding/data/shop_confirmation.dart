/// The shop's answer to a builder's selection.
///
/// Selecting a shop is no longer the end of it: the shop confirms the order,
/// or backs out, from the dashboard. The dashboard writes `shopConfirmation`
/// on the quotation; the builder app only reads it. Chat and rating wait for a
/// confirmation, because until then the shop has not agreed to anything.
library;

enum ShopConfirmation {
  /// Selected by the builder, not yet answered by the shop.
  pending,

  /// The shop took the order at the builder's accepted total.
  confirmed,

  /// The shop turned the order down. Terminal: the quotation is also marked
  /// rejected by the dashboard.
  declined,
}

/// Reads `shopConfirmation` off a quotation document.
///
/// A quotation from before shops had to confirm carries no field at all. It
/// reads as confirmed, so a deal that was already working does not suddenly
/// look like it is waiting on the shop. A value this app does not know is
/// treated the same way rather than locking the builder out.
ShopConfirmation shopConfirmationOf(Map<String, dynamic> quotation) {
  final raw = '${quotation['shopConfirmation'] ?? ''}'.trim().toLowerCase();
  return switch (raw) {
    'pending' => ShopConfirmation.pending,
    'declined' => ShopConfirmation.declined,
    _ => ShopConfirmation.confirmed,
  };
}
