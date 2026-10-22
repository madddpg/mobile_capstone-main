import 'package:flutter_test/flutter_test.dart';

import 'package:iconstruct/features/bidding/data/shop_confirmation.dart';

/// Accepting a quotation is final: the builder does not wait for the shop.
/// The one answer the shop can still give is to back out ("declined").

void main() {
  test('an accepted quotation is a deal without the shop confirming', () {
    expect(shopConfirmationOf({'status': 'accepted'}),
        ShopConfirmation.confirmed);
    expect(shopConfirmationOf({'shopConfirmation': 'confirmed'}),
        ShopConfirmation.confirmed);
  });

  test('a stored "pending" no longer holds the builder back', () {
    // The dashboard may still write it at acceptance.
    expect(shopConfirmationOf({'shopConfirmation': 'pending'}),
        ShopConfirmation.confirmed);
    expect(shopConfirmationOf({'shopConfirmation': ' Pending '}),
        ShopConfirmation.confirmed);
  });

  test('a shop that backs out reads as declined', () {
    expect(shopConfirmationOf({'shopConfirmation': 'declined'}),
        ShopConfirmation.declined);
    expect(shopConfirmationOf({'shopConfirmation': ' Declined '}),
        ShopConfirmation.declined);
  });

  test('an unknown answer does not lock the builder out', () {
    expect(shopConfirmationOf({'shopConfirmation': 'maybe'}),
        ShopConfirmation.confirmed);
  });
}
