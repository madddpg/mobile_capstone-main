import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconstruct/core/theme/app_theme.dart';
import 'package:iconstruct/core/widgets/app_message.dart';
import 'package:iconstruct/core/widgets/iconstruct_panel.dart';
import 'package:iconstruct/features/auth/presentation/models/ranked_shop.dart';
import 'package:iconstruct/features/auth/presentation/models/shop_rating.dart';
import 'package:iconstruct/features/auth/presentation/services/shop_rating_service.dart';
import 'package:iconstruct/features/auth/presentation/widgets/shop_rating_stars.dart';

/// Lets a builder rate a shop they actually bought from.
///
/// Only projects where this builder selected this shop can be rated, and the
/// security rules check the same thing on the way in. A rating that anyone
/// could leave would say nothing about the shop, so the constraint is the
/// feature rather than a limitation of it.
///
/// Returns true when a rating was saved, so the caller can refresh.
Future<bool> showRateShopSheet(BuildContext context, RankedShop shop) async {
  final service = ShopRatingService();

  final projects = await service.ratableProjects(shop.uid);
  if (!context.mounted) return false;

  if (projects.isEmpty) {
    showAppMessage(
      context,
      SnackBar(
        content: Text(
          'You can rate ${shop.shopName} once you have chosen them as a '
          'supplier on one of your estimates.',
        ),
      ),
    );
    return false;
  }

  final existing = await service.myRating(shop.uid);
  if (!context.mounted) return false;

  final saved = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => _RateShopSheet(
      shop: shop,
      projects: projects,
      existing: existing,
      service: service,
    ),
  );

  return saved == true;
}

class _RateShopSheet extends StatefulWidget {
  final RankedShop shop;
  final List<({String postId, String title})> projects;
  final ShopRatingDraft? existing;
  final ShopRatingService service;

  const _RateShopSheet({
    required this.shop,
    required this.projects,
    required this.existing,
    required this.service,
  });

  @override
  State<_RateShopSheet> createState() => _RateShopSheetState();
}

class _RateShopSheetState extends State<_RateShopSheet> {
  late int _stars;
  late String _postId;
  late final TextEditingController _comment;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _stars = widget.existing?.stars ?? 0;
    _comment = TextEditingController(text: widget.existing?.comment ?? '');

    // Reopen on the project the builder rated before, when that project is
    // still one of theirs; otherwise start on the most recent.
    final previous = widget.existing?.postId;
    final known = widget.projects.any((p) => p.postId == previous);
    _postId = known ? previous! : widget.projects.first.postId;
  }

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  /// Plain words for each score, so the meaning of three stars is not left to
  /// the builder to guess.
  static String _starMeaning(int stars) => switch (stars) {
        1 => 'Poor — I would not order from them again',
        2 => 'Below what I expected',
        3 => 'Fine — the order was filled',
        4 => 'Good — I would order again',
        5 => 'Excellent — I would recommend them',
        _ => 'Tap a star to rate this shop',
      };

  Future<void> _save() async {
    if (_stars < 1 || _saving) return;
    setState(() => _saving = true);

    try {
      await widget.service.submit(
        shopId: widget.shop.uid,
        draft: ShopRatingDraft(
          stars: _stars,
          postId: _postId,
          comment: _comment.text,
        ),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
      showAppMessage(
        context,
        const SnackBar(content: Text('Thanks, your rating was saved.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showAppMessage(
        context,
        SnackBar(
          content: Text(
            'That rating did not save. ${e.toString().replaceFirst(RegExp(r'^\w+: '), '')}',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final multipleProjects = widget.projects.length > 1;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
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
              margin: const EdgeInsets.only(top: 10, bottom: 14),
              decoration: BoxDecoration(
                color: AppColors.cream.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                children: [
                  Text(
                    widget.existing == null
                        ? 'Rate ${widget.shop.shopName}'
                        : 'Update your rating',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 14),
                  StarPicker(
                    value: _stars,
                    onChanged: (v) => setState(() => _stars = v),
                    color: Colors.amber.shade600,
                    emptyColor: AppColors.cream.withValues(alpha: 0.35),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _starMeaning(_stars),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 12.5,
                      color: IConstructPanel.creamSoft,
                      height: 1.4,
                    ),
                  ),
                  if (multipleProjects) ...[
                    const SizedBox(height: 18),
                    Text(
                      'WHICH ESTIMATE',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                        color: AppColors.cream.withValues(alpha: 0.65),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: IConstructPanel.darkBlue,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppColors.cream.withValues(alpha: 0.3),
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _postId,
                          isExpanded: true,
                          dropdownColor: IConstructPanel.darkBlue,
                          iconEnabledColor: AppColors.cream,
                          style: GoogleFonts.poppins(
                            fontSize: 12.5,
                            color: AppColors.cream,
                          ),
                          items: [
                            for (final p in widget.projects)
                              DropdownMenuItem(
                                value: p.postId,
                                child: Text(
                                  p.title,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          onChanged: (v) =>
                              setState(() => _postId = v ?? _postId),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextField(
                    controller: _comment,
                    maxLines: 3,
                    maxLength: 500,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: AppColors.textDark,
                    ),
                    decoration: InputDecoration(
                      hintText: 'What went well, or what did not? Optional.',
                      hintStyle: GoogleFonts.poppins(fontSize: 12.5),
                      filled: true,
                      fillColor: AppColors.cream,
                      counterStyle: GoogleFonts.poppins(
                        fontSize: 10,
                        color: IConstructPanel.creamSoft,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: (_stars < 1 || _saving) ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.cream,
                        foregroundColor: IConstructPanel.navy,
                        disabledBackgroundColor:
                            AppColors.cream.withValues(alpha: 0.35),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              _stars < 1
                                  ? 'Pick a star rating'
                                  : widget.existing == null
                                      ? 'Submit rating'
                                      : 'Update rating',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your rating is public and shown with this shop. '
                    'Only builders who chose this shop can rate it.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: IConstructPanel.creamSoft,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
