import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconstruct/features/auth/presentation/models/shop_rating.dart';

/// Five stars plus the score, as it appears on a shop card.
///
/// A shop nobody has rated shows "New shop" rather than five empty stars,
/// because empty stars read as a bad shop rather than an unrated one, and a
/// new hardware store should not look worse than a mediocre established one.
class ShopRatingStars extends StatelessWidget {
  final ShopRating rating;
  final double size;
  final Color color;
  final Color emptyColor;
  final Color textColor;

  /// Shows the count beside the score. Off in tight rows.
  final bool showCount;

  const ShopRatingStars({
    super.key,
    required this.rating,
    this.size = 14,
    required this.color,
    required this.emptyColor,
    required this.textColor,
    this.showCount = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!rating.hasRatings) {
      return Text(
        'New shop',
        style: GoogleFonts.poppins(
          fontSize: size * 0.8,
          fontWeight: FontWeight.w600,
          color: textColor.withValues(alpha: 0.7),
        ),
      );
    }

    final fills = starFills(rating.displayStars);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final fill in fills)
          Padding(
            padding: const EdgeInsets.only(right: 1),
            child: Icon(
              // A half star is its own glyph rather than a clipped full one,
              // which keeps the row crisp at small sizes.
              fill >= 0.75
                  ? Icons.star_rounded
                  : fill >= 0.25
                      ? Icons.star_half_rounded
                      : Icons.star_outline_rounded,
              size: size,
              color: fill >= 0.25 ? color : emptyColor,
            ),
          ),
        SizedBox(width: size * 0.35),
        Text(
          rating.averageLabel,
          style: GoogleFonts.poppins(
            fontSize: size * 0.82,
            fontWeight: FontWeight.w700,
            color: textColor,
          ),
        ),
        if (showCount) ...[
          SizedBox(width: size * 0.25),
          Text(
            '(${rating.count})',
            style: GoogleFonts.poppins(
              fontSize: size * 0.75,
              color: textColor.withValues(alpha: 0.7),
            ),
          ),
        ],
      ],
    );
  }
}

/// The five tappable stars a builder sets their own score with.
class StarPicker extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  final double size;
  final Color color;
  final Color emptyColor;

  const StarPicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.size = 38,
    required this.color,
    required this.emptyColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var star = 1; star <= 5; star++)
          Semantics(
            button: true,
            label: '$star ${star == 1 ? 'star' : 'stars'}',
            selected: value == star,
            child: IconButton(
              onPressed: () => onChanged(star),
              iconSize: size,
              padding: const EdgeInsets.symmetric(horizontal: 2),
              constraints: const BoxConstraints(),
              icon: Icon(
                star <= value ? Icons.star_rounded : Icons.star_outline_rounded,
                color: star <= value ? color : emptyColor,
              ),
            ),
          ),
      ],
    );
  }
}
