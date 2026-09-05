import 'package:flutter_test/flutter_test.dart';

import 'package:iconstruct/features/bidding/data/quotation_accept_service.dart';

void main() {
  group('postedEstimateOwnerId', () {
    test('prefers userId, the field Firestore rules check first', () {
      expect(
        postedEstimateOwnerId({
          'userId': 'auth-uid',
          'builderId': 'other',
        }),
        'auth-uid',
      );
    });

    test('falls back to builderId, ownerId, then postedBy', () {
      expect(postedEstimateOwnerId({'builderId': 'b1'}), 'b1');
      expect(postedEstimateOwnerId({'ownerId': 'o1'}), 'o1');
      expect(postedEstimateOwnerId({'postedBy': 'p1'}), 'p1');
      expect(postedEstimateOwnerId({}), isNull);
    });
  });

  group('isPostedEstimateOwner', () {
    test('matches Auth uid on any owner alias', () {
      expect(isPostedEstimateOwner({'userId': 'u1'}, 'u1'), isTrue);
      expect(isPostedEstimateOwner({'builderId': 'u1'}, 'u1'), isTrue);
      expect(isPostedEstimateOwner({'userId': 'shop'}, 'u1'), isFalse);
    });
  });

  group('quotationShopId', () {
    test('uses shopId field, then the quotation document id', () {
      expect(quotationShopId({'shopId': 'shop-a'}, 'doc-1'), 'shop-a');
      expect(quotationShopId({}, 'shop-a'), 'shop-a');
    });
  });
}
