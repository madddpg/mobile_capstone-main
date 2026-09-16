/// A hardware shop's rating, as shown to builders.
///
/// Ratings are aggregated server-side onto the shop document. A builder cannot
/// write to a shop document, so the average and the count are read here and
/// never computed from the raw rating documents on the client: doing that would
/// mean downloading every rating a shop ever received just to draw five stars.
class ShopRating {
  /// Mean score, 1 to 5. Zero when nobody has rated the shop yet.
  final double average;

  /// How many builders have rated the shop.
  final int count;

  const ShopRating({this.average = 0, this.count = 0});

  static const ShopRating none = ShopRating();

  /// A shop with no ratings is shown as new rather than as zero stars, which
  /// would read as a bad shop rather than an unrated one.
  bool get hasRatings => count > 0 && average > 0;

  /// Rounded to the half star the display actually draws.
  double get displayStars => (average * 2).round() / 2;

  /// One decimal, the way review scores are normally written.
  String get averageLabel => average.toStringAsFixed(1);

  String get countLabel => count == 1 ? '1 rating' : '$count ratings';

  /// Short summary for a card: "4.5 (12)", or a word when there is nothing yet.
  String get summaryLabel => hasRatings ? '$averageLabel ($count)' : 'New shop';

  /// Reads the summary the Cloud Function computes from builder ratings.
  ///
  /// Only `rating` and `ratingCount` are trusted, because only the function
  /// can write them. This used to fall back to other spellings
  /// (`averageRating`, `reviewCount` and so on) in case the web dashboard had
  /// written them. A shop owner could fill those in on their own document, and
  /// the app would show and rank by the made-up score. Records with neither
  /// field, including shops nobody has rated, show as a new shop.
  factory ShopRating.fromShopData(Map<String, dynamic> data) {
    double asDouble(Object? v) {
      if (v is num) return v.toDouble();
      return double.tryParse('${v ?? ''}') ?? 0;
    }

    int asInt(Object? v) {
      if (v is num) return v.toInt();
      return int.tryParse('${v ?? ''}') ?? 0;
    }

    final average = asDouble(data['rating']);
    final count = asInt(data['ratingCount']);

    // A stored average outside 1 to 5 means something wrote a bad value; show
    // the shop as unrated rather than drawing six stars.
    if (count <= 0 || average < 1 || average > 5) return none;
    return ShopRating(average: average, count: count);
  }
}

/// How full each of the five stars should be drawn, left to right.
///
/// Returns a fill from 0 to 1 per star so a 4.5 gives four full stars and one
/// half, without the caller repeating the arithmetic.
List<double> starFills(double stars) {
  final clamped = stars.clamp(0.0, 5.0);
  return List<double>.generate(
    5,
    (i) => (clamped - i).clamp(0.0, 1.0).toDouble(),
  );
}

/// What a builder submits.
class ShopRatingDraft {
  /// Whole stars, 1 to 5.
  final int stars;

  /// Optional short comment.
  final String comment;

  /// The posted estimate this rating is based on. Required, because only a
  /// builder who actually selected this shop for a project may rate it, and
  /// the security rules verify that against this id.
  final String postId;

  const ShopRatingDraft({
    required this.stars,
    required this.postId,
    this.comment = '',
  });

  bool get isValid => stars >= 1 && stars <= 5 && postId.trim().isNotEmpty;

  Map<String, dynamic> toMap() => {
        'stars': stars,
        'comment': comment.trim(),
        'postId': postId.trim(),
      };
}
