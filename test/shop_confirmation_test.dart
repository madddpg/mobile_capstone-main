import 'package:flutter_test/flutter_test.dart';

import 'package:iconstruct/features/bidding/data/shop_confirmation.dart';

/// The shop confirms a selection from the dashboard. The builder app only
/// reads the answer, and chat and rating wait for it.

void main() {
  test('reads each answer the dashboard writes', () {
    expect(shopConfirmationOf({'shopConfirmation': 'pending'}),
        ShopConfirmation.pending);
    expect(shopConfirmationOf({'shopConfirmation': 'confirmed'}),
        ShopConfirmation.confirmed);
    expect(shopConfirmationOf({'shopConfirmation': 'declined'}),
        ShopConfirmation.declined);
  });

  test('a quotation from before shops confirmed reads as confirmed', () {
    // Deals that were already working must not suddenly look pending.
    expect(shopConfirmationOf({'status': 'accepted'}),
        ShopConfirmation.confirmed);
  });

  test('tolerates case and spacing', () {
    expect(shopConfirmationOf({'shopConfirmation': ' Pending '}),
        ShopConfirmation.pending);
  });

  test('an unknown answer does not lock the builder out', () {
    expect(shopConfirmationOf({'shopConfirmation': 'maybe'}),
        ShopConfirmation.confirmed);
  });
}
