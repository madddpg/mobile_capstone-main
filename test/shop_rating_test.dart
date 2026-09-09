import 'package:flutter_test/flutter_test.dart';
import 'package:iconstruct/features/auth/presentation/models/shop_rating.dart';

/// A rating drives which shops a builder canvasses, so a wrong number here
/// steers real spending. These pin the reading and the display maths.
void main() {
  group('ShopRating.fromShopData', () {
    test('reads the fields the aggregation writes', () {
      final r = ShopRating.fromShopData({'rating': 4.5, 'ratingCount': 12});
      expect(r.hasRatings, isTrue);
      expect(r.average, 4.5);
      expect(r.count, 12);
    });

    test('accepts the other spellings the dashboard may have written', () {
      for (final pair in [
        {'averageRating': 4.0, 'ratingsCount': 3},
        {'ratingAverage': 4.0, 'reviewCount': 3},
      ]) {
        final r = ShopRating.fromShopData(pair);
        expect(r.average, 4.0, reason: 'failed for ${pair.keys}');
        expect(r.count, 3);
      }
    });

    test('a shop nobody has rated is unrated, not zero stars', () {
      // Zero stars reads as a bad shop. A new hardware store must not look
      // worse than a mediocre established one.
      final r = ShopRating.fromShopData({'shopName': 'New Hardware'});
      expect(r.hasRatings, isFalse);
      expect(r.summaryLabel, 'New shop');
    });

    test('a count of zero is unrated even if an average was left behind', () {
      final r = ShopRating.fromShopData({'rating': 4.8, 'ratingCount': 0});
      expect(r.hasRatings, isFalse);
    });

    test('an out-of-range average is treated as unrated', () {
      // Six stars would draw off the end of the row, so a bad stored value is
      // shown as no rating rather than trusted.
      for (final bad in [0.0, -2.0, 5.7, 99.0]) {
        final r = ShopRating.fromShopData({'rating': bad, 'ratingCount': 4});
        expect(r.hasRatings, isFalse, reason: 'accepted $bad');
      }
    });

    test('numbers stored as strings still parse', () {
      final r = ShopRating.fromShopData({'rating': '4.2', 'ratingCount': '7'});
      expect(r.average, 4.2);
      expect(r.count, 7);
    });
  });

  group('display', () {
    test('the average rounds to the half star that is drawn', () {
      expect(const ShopRating(average: 4.4, count: 5).displayStars, 4.5);
      expect(const ShopRating(average: 4.2, count: 5).displayStars, 4.0);
      expect(const ShopRating(average: 4.75, count: 5).displayStars, 5.0);
    });

    test('the score reads to one decimal', () {
      expect(const ShopRating(average: 4.0, count: 2).averageLabel, '4.0');
      expect(const ShopRating(average: 3.666, count: 3).averageLabel, '3.7');
    });

    test('one rating is singular', () {
      expect(const ShopRating(average: 5, count: 1).countLabel, '1 rating');
      expect(const ShopRating(average: 5, count: 2).countLabel, '2 ratings');
    });
  });

  group('starFills', () {
    test('a whole score fills exactly that many stars', () {
      expect(starFills(3), [1.0, 1.0, 1.0, 0.0, 0.0]);
    });

    test('a half score leaves one star half full', () {
      expect(starFills(3.5), [1.0, 1.0, 1.0, 0.5, 0.0]);
    });

    test('five fills every star and nothing overflows', () {
      expect(starFills(5), [1.0, 1.0, 1.0, 1.0, 1.0]);
    });

    test('a score beyond the scale is clamped rather than drawn', () {
      expect(starFills(9), [1.0, 1.0, 1.0, 1.0, 1.0]);
      expect(starFills(-3), [0.0, 0.0, 0.0, 0.0, 0.0]);
    });
  });

  group('ShopRatingDraft', () {
    test('a draft needs a score and the project it came from', () {
      expect(
        const ShopRatingDraft(stars: 4, postId: 'post-1').isValid,
        isTrue,
      );
      // Without a project the rules cannot verify the builder dealt with this
      // shop, so the write would be rejected anyway.
      expect(const ShopRatingDraft(stars: 4, postId: '').isValid, isFalse);
      expect(const ShopRatingDraft(stars: 0, postId: 'p').isValid, isFalse);
      expect(const ShopRatingDraft(stars: 6, postId: 'p').isValid, isFalse);
    });

    test('the comment is trimmed on the way out', () {
      const draft =
          ShopRatingDraft(stars: 5, postId: 'p', comment: '  fast delivery  ');
      expect(draft.toMap()['comment'], 'fast delivery');
    });
  });
}
