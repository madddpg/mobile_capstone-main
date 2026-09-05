import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconstruct/features/project_creation/data/material_sources.dart';
import 'package:iconstruct/features/project_creation/data/material_visual.dart';
import 'package:iconstruct/features/project_creation/widgets/material_swatch.dart';

const _kInk = Color(0xFF1E3042);
const _kPanel = Color(0xFF16242F);
const _kCream = Color(0xFFEDE4D4);
const _kMuted = Color(0xFFE0D7C9);
const _kBlue = Color(0xFF8FB2D4);
const _kWarn = Color(0xFFFFB86B);
const _kGood = Color(0xFF6EE7B7);

/// The material identification card.
///
/// Answers the question a canvasser actually has at the counter: *is the thing
/// being handed to me the thing on my list?* A quantity and a name are not
/// enough, because the two ways a canvass goes wrong are buying the lookalike
/// and accepting an under-spec substitution.
///
/// Opened by tapping the swatch on any BOM row.
Future<void> showMaterialIdSheet(
  BuildContext context, {
  required String name,
  required String category,
  required String unit,
  required double quantity,
  String? size,
}) {
  final visual = MaterialVisual.forItem(
    name: name,
    category: category,
    unit: unit,
  );

  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => _MaterialIdSheet(
      visual: visual,
      name: name,
      category: category,
      unit: unit,
      quantity: quantity,
      size: size,
    ),
  );
}

class _MaterialIdSheet extends StatelessWidget {
  final MaterialVisual visual;
  final String name;
  final String category;
  final String unit;
  final double quantity;
  final String? size;

  const _MaterialIdSheet({
    required this.visual,
    required this.name,
    required this.category,
    required this.unit,
    required this.quantity,
    required this.size,
  });

  String get _qtyLabel {
    final q = quantity == quantity.roundToDouble()
        ? quantity.toInt().toString()
        : quantity.toStringAsFixed(1);
    return '$q $unit';
  }

  /// The single line a user can read aloud, or paste into a chat with a
  /// supplier, and get the right item quoted.
  String get _orderLine {
    final spec = (size ?? '').trim();
    return [
      _qtyLabel,
      '—',
      name,
      if (spec.isNotEmpty) '($spec)',
    ].join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.86;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: const BoxDecoration(
        color: _kInk,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 4,
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            decoration: BoxDecoration(
              color: _kCream.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
              children: [
                _header(),
                const SizedBox(height: 18),
                _orderLineCard(context),
                const SizedBox(height: 14),
                _block(
                  icon: Icons.visibility_outlined,
                  tint: _kBlue,
                  title: 'What it looks like',
                  body: visual.looksLike,
                ),
                _block(
                  icon: Icons.record_voice_over_outlined,
                  tint: _kGood,
                  title: 'What to say at the counter',
                  body: visual.counterCallout,
                ),
                _block(
                  icon: Icons.inventory_2_outlined,
                  tint: _kCream,
                  title: 'How it is sold',
                  body: visual.packaging,
                ),
                if (visual.lookalike != null)
                  _block(
                    icon: Icons.warning_amber_rounded,
                    tint: _kWarn,
                    title: 'Do not confuse it with',
                    body: visual.lookalike!,
                  ),
                if (visual.acceptance != null)
                  _block(
                    icon: Icons.fact_check_outlined,
                    tint: _kGood,
                    title: 'Check before you accept delivery',
                    body: visual.acceptance!,
                  ),
                _sources(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _header() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Large render of the same glyph shown on the list row, so the user is
        // matching against exactly what they tapped.
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _kPanel,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _kCream.withValues(alpha: 0.22)),
          ),
          child: MaterialSwatch(
            visual: visual,
            size: size,
            dimension: 84,
            showPlate: false,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (category.isNotEmpty) _chip(category),
                  if ((size ?? '').trim().isNotEmpty) _chip(size!.trim()),
                  _chip(_qtyLabel, strong: true),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _chip(String text, {bool strong = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: strong ? _kCream : _kCream.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kCream.withValues(alpha: 0.35)),
      ),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          color: strong ? _kInk : _kMuted,
        ),
      ),
    );
  }

  Widget _orderLineCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: _kPanel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kGood.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'READ THIS OUT WHEN ORDERING',
                  style: GoogleFonts.poppins(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.7,
                    color: _kGood,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _orderLine,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Copy',
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: _orderLine));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Order line copied'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            icon: const Icon(Icons.copy_rounded, size: 18, color: _kCream),
          ),
        ],
      ),
    );
  }

  /// Provenance. Shown on every material so the estimate can be defended
  /// line by line, and so a coefficient is never mistaken for a standard.
  Widget _sources() {
    final sources = MaterialSources.forItem(
      name: name,
      category: category,
      unit: unit,
    );
    if (sources.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: _kPanel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBlue.withValues(alpha: 0.30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_balance_outlined, size: 15, color: _kBlue),
              const SizedBox(width: 7),
              Text(
                'Where this comes from',
                style: GoogleFonts.poppins(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: _kBlue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          for (final src in sources) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 2, right: 7),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _tierColor(src.tier).withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: _tierColor(src.tier).withValues(alpha: 0.55),
                          ),
                        ),
                        child: Text(
                          src.tierLabel,
                          style: GoogleFonts.poppins(
                            fontSize: 8.5,
                            fontWeight: FontWeight.w700,
                            color: _tierColor(src.tier),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          '${src.authority} — ${src.reference}',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    src.covers,
                    style: GoogleFonts.poppins(
                      fontSize: 10.5,
                      color: _kMuted,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  static Color _tierColor(SourceTier tier) => switch (tier) {
        SourceTier.nationalStandard => _kGood,
        SourceTier.referenceText => _kBlue,
        SourceTier.tradePractice => _kWarn,
      };

  Widget _block({
    required IconData icon,
    required Color tint,
    required String title,
    required String body,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: _kPanel,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: tint.withValues(alpha: 0.30)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 15, color: tint),
                const SizedBox(width: 7),
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: tint,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            Text(
              body,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: _kMuted,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
