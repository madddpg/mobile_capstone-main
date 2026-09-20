import 'package:flutter_test/flutter_test.dart';

import 'package:iconstruct/features/auth/presentation/models/ranked_shop.dart';
import 'package:iconstruct/features/auth/presentation/widgets/shop_storefront_sheet.dart';

/// A shop document as the web dashboard writes it.
const _shopDoc = <String, dynamic>{
  'shopName': 'gishop',
  'ownerName': 'Gina Santos',
  'status': 'approved',
  'description': 'Hardware and construction supply since 2008.',
  'businessHours': 'Mon-Sat, 7 AM - 6 PM',
  'coverageCities': ['Marauoy, Lipa City', 'Sabang, Lipa City'],
  'suppliedCategories': ['cement_aggregates', 'steel_rebar', 'tiles_masonry_finish'],
  'phone': '0917 555 0101',
  'address': '12 Rizal St',
  'barangay': 'Marauoy',
  'city': 'Lipa City',
  'subscriptionPlan': 'pro',
  'rating': 4.5,
  'ratingCount': 12,
};

void main() {
  group('RankedShop.fromMap', () {
    final shop = RankedShop.fromMap('shop-1', _shopDoc);

    test('reads the storefront a builder judges the quote by', () {
      expect(shop.uid, 'shop-1');
      expect(shop.shopName, 'gishop');
      expect(shop.phone, '0917 555 0101');
      expect(shop.businessHours, 'Mon-Sat, 7 AM - 6 PM');
      expect(shop.coverageCities, hasLength(2));
      expect(shop.rating.hasRatings, isTrue);
      expect(shop.rating.summaryLabel, '4.5 (12)');
    });

    test('a shop that filled in nothing still parses', () {
      final empty = RankedShop.fromMap('shop-2', const {});
      expect(empty.shopName, 'Unknown Shop');
      expect(empty.coverageCities, isEmpty);
      expect(empty.rating.hasRatings, isFalse);
      expect(empty.hasStorefront, isFalse);
    });

    test('the uid field wins over the document id, when they disagree', () {
      final shop = RankedShop.fromMap('doc-id', const {'uid': 'auth-uid'});
      expect(shop.uid, 'auth-uid');
    });
  });

  group('card lines', () {
    test('the location is the town, so a card line stays short', () {
      expect(RankedShop.fromMap('s', _shopDoc).shortLocation, 'Lipa City');
    });

    test('a shop with only coverage areas shows the first one', () {
      final shop = RankedShop.fromMap('s', const {
        'coverageCities': ['Santo Tomas', 'Malvar'],
      });
      expect(shop.shortLocation, 'Santo Tomas');
    });

    test('the full address is kept for the details sheet', () {
      expect(
        RankedShop.fromMap('s', _shopDoc).locationLabel,
        '12 Rizal St, Marauoy, Lipa City',
      );
    });

    test('only a paid plan is worth a badge', () {
      expect(RankedShop.fromMap('s', _shopDoc).planLabel, 'Pro');
      expect(
        RankedShop.fromMap('s', const {'subscriptionPlan': 'business'}).planLabel,
        'Business',
      );
      expect(
        RankedShop.fromMap('s', const {'subscriptionPlan': 'basic'}).planLabel,
        '',
      );
      expect(RankedShop.fromMap('s', const {}).planLabel, '');
    });
  });

  group('supplyCategoryLabel', () {
    test('reads the keys the dashboard category picker writes', () {
      expect(supplyCategoryLabel('cement_aggregates'), 'Cement & aggregates');
      expect(supplyCategoryLabel('hardware_fasteners'), 'Hardware & fasteners');
      expect(supplyCategoryLabel('tiles_masonry_finish'), 'Tiles & masonry');
      expect(supplyCategoryLabel('doors_windows'), 'Doors & windows');
      expect(supplyCategoryLabel('tools_equipment'), 'Tools & equipment');
    });

    test('older shorter keys still read', () {
      expect(supplyCategoryLabel('cement'), 'Cement & aggregates');
      expect(supplyCategoryLabel('tiles'), 'Tiles');
    });

    test('a category added on the web is tidied up, not hidden', () {
      expect(supplyCategoryLabel('glass_aluminium'), 'Glass aluminium');
    });
  });
}
