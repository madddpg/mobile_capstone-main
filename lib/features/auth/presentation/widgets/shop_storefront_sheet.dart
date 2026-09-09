import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconstruct/core/theme/app_theme.dart';
import 'package:iconstruct/core/widgets/iconstruct_panel.dart';
import 'package:iconstruct/features/auth/presentation/models/ranked_shop.dart';
import 'package:iconstruct/features/auth/presentation/widgets/shop_rating_stars.dart';
import 'package:iconstruct/features/auth/presentation/widgets/rate_shop_sheet.dart';

/// Labels for the category keys the shop's dashboard stores.
///
/// The dashboard saves keys rather than words so the two apps can be worded
/// differently. An unknown key is shown tidied up rather than hidden, since a
/// category the builder cannot see is worse than one phrased awkwardly.
const Map<String, String> kSupplyCategoryLabels = {
  'tiles': 'Tiles',
  'cement': 'Cement & aggregates',
  'aggregates': 'Sand & gravel',
  'steel': 'Steel & rebar',
  'masonry': 'CHB & masonry',
  'roofing': 'Roofing',
  'lumber': 'Lumber & plywood',
  'paint': 'Paint & finishes',
  'plumbing': 'Plumbing',
  'electrical': 'Electrical',
  'hardware': 'General hardware',
  'tools': 'Tools',
  'waterproofing': 'Waterproofing',
  'fixtures': 'Fixtures',
};

String supplyCategoryLabel(String key) {
  final k = key.trim().toLowerCase();
  final known = kSupplyCategoryLabels[k];
  if (known != null) return known;
  if (key.trim().isEmpty) return key;
  final cleaned = key.trim().replaceAll('_', ' ');
  return cleaned[0].toUpperCase() + cleaned.substring(1);
}

/// The shop's storefront, as the builder sees it.
///
/// Read-only by design. Shops maintain their own profile on the web dashboard;
/// this app shows what they wrote so a builder can judge whether a shop is
/// worth canvassing before spending a quotation round on them.
Future<void> showShopStorefrontSheet(BuildContext context, RankedShop shop) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => _StorefrontSheet(shop: shop),
  );
}

class _StorefrontSheet extends StatelessWidget {
  final RankedShop shop;

  const _StorefrontSheet({required this.shop});

  @override
  Widget build(BuildContext context) {
    final location = [shop.address, shop.barangay, shop.city]
        .where((s) => s.trim().isNotEmpty)
        .join(', ');

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: IConstructPanel.navy,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 4,
            margin: const EdgeInsets.only(top: 10, bottom: 8),
            decoration: BoxDecoration(
              color: AppColors.cream.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 26),
              children: [
                Text(
                  shop.shopName,
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1.2,
                  ),
                ),
                if (location.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    location,
                    style: GoogleFonts.poppins(
                      fontSize: 12.5,
                      color: IConstructPanel.creamSoft,
                      height: 1.4,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                ShopRatingStars(
                  rating: shop.rating,
                  size: 17,
                  color: Colors.amber.shade600,
                  emptyColor: AppColors.cream.withValues(alpha: 0.3),
                  textColor: Colors.white,
                ),
                if (shop.description.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    shop.description,
                    style: GoogleFonts.poppins(
                      fontSize: 13.5,
                      color: Colors.white,
                      height: 1.45,
                    ),
                  ),
                ],
                if (shop.businessHours.isNotEmpty)
                  _row(Icons.schedule_rounded, 'Hours', shop.businessHours),
                if (shop.coverageCities.isNotEmpty)
                  _row(
                    Icons.place_outlined,
                    'Serves',
                    shop.coverageCities.join(', '),
                  ),
                _row(
                  Icons.receipt_long_outlined,
                  'Quotes sent',
                  '${shop.quotationCount}',
                ),
                if (shop.suppliedCategories.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  _heading('What they supply'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: [
                      for (final key in shop.suppliedCategories)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.cream.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: AppColors.cream.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Text(
                            supplyCategoryLabel(key),
                            style: GoogleFonts.poppins(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.cream,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
                if (shop.storefrontAbout.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  _heading('About'),
                  const SizedBox(height: 6),
                  Text(
                    shop.storefrontAbout,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: IConstructPanel.creamSoft,
                      height: 1.5,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: () => showRateShopSheet(context, shop),
                  icon: const Icon(Icons.star_outline_rounded, size: 18),
                  label: Text(
                    'Rate this shop',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.cream,
                    side: BorderSide(
                      color: AppColors.cream.withValues(alpha: 0.45),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                ),
                if (!shop.hasStorefront) ...[
                  const SizedBox(height: 16),
                  Text(
                    'This shop has not filled in its storefront yet. '
                    'You can still post your estimate and they can quote it.',
                    style: GoogleFonts.poppins(
                      fontSize: 12.5,
                      color: IConstructPanel.creamSoft,
                      height: 1.45,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _heading(String text) => Text(
        text.toUpperCase(),
        style: GoogleFonts.poppins(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
          color: AppColors.cream.withValues(alpha: 0.65),
        ),
      );

  Widget _row(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.cream.withValues(alpha: 0.75)),
          const SizedBox(width: 9),
          Expanded(
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: '$label  ',
                    style: GoogleFonts.poppins(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.cream.withValues(alpha: 0.7),
                    ),
                  ),
                  TextSpan(
                    text: value,
                    style: GoogleFonts.poppins(
                      fontSize: 12.5,
                      color: Colors.white,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
