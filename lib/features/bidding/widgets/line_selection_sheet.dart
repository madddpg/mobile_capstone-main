import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconstruct/core/theme/app_theme.dart';
import 'package:iconstruct/features/bidding/data/bid_comparison.dart';
import 'package:iconstruct/features/bidding/data/partial_acceptance.dart';

/// Result of asking the builder which quoted lines to take.
class LineSelectionResult {
  /// Positions the builder kept, indexed against the quotation's own items
  /// array. Null means the quotation carries no itemised lines, so the whole
  /// offer is accepted as one.
  final Set<int>? acceptedIndexes;
  final double acceptedTotal;
  final int acceptedCount;
  final int totalCount;

  const LineSelectionResult({
    required this.acceptedIndexes,
    required this.acceptedTotal,
    required this.acceptedCount,
    required this.totalCount,
  });

  bool get isPartial =>
      acceptedIndexes != null && acceptedCount < totalCount;
}

/// Lets the builder choose which lines of a shop's quotation to accept.
///
/// Reads the quotation document directly rather than taking the parsed
/// comparison model, because that model merges duplicate names and would give
/// positions that no longer line up with the array the acceptance writes back.
/// Selecting on the stored array keeps every index honest.
///
/// Returns null if the builder backs out.
Future<LineSelectionResult?> showLineSelectionSheet(
  BuildContext context, {
  required String postId,
  required String quotationId,
  required String shopName,
}) async {
  var items = <Map<String, dynamic>>[];
  var quotedTotal = 0.0;
  try {
    final snap = await FirebaseFirestore.instance
        .collection('projectPosts')
        .doc(postId)
        .collection('quotations')
        .doc(quotationId)
        .get();
    final data = snap.data() ?? <String, dynamic>{};
    items = quotationItems(data);
    quotedTotal = bidAsDouble(
      data['estimatedTotal'] ?? data['totalAmount'] ?? data['amount'],
    );
  } catch (_) {
    items = const [];
  }

  if (!context.mounted) return null;

  return showModalBottomSheet<LineSelectionResult>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => SelectShopSheet(
      items: items,
      shopName: shopName,
      quotedTotal: quotedTotal,
    ),
  );
}

const _sheetBg = Color(0xFFF6F3EE);
const _border = Color(0xFFE4DED3);
const _subBorder = Color(0xFFF3C969);
const _subTint = Color(0xFFFFFBF0);
const _subText = Color(0xFFB45309);

String _money(double v) {
  final whole = v.round().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < whole.length; i++) {
    if (i > 0 && (whole.length - i) % 3 == 0) buffer.write(',');
    buffer.write(whole[i]);
  }
  return '₱$buffer';
}

String _number(Object? raw) {
  final v = bidAsDouble(raw);
  if (v <= 0) return '';
  return v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
}

/// "20 bags × ₱343", as the shop dashboard writes it.
String _quantityLine(Map<String, dynamic> item) {
  final qty = _number(item['quantity'] ?? item['qty']);
  final unit = '${item['unit'] ?? ''}'.trim();
  final size = '${item['size'] ?? ''}'.trim();
  final price = bidAsDouble(item['unitPrice'] ?? item['price']);
  final parts = <String>[
    if (qty.isNotEmpty) '$qty $unit'.trim(),
    if (size.isNotEmpty) size,
  ];
  final amount = parts.join(' · ');
  if (price <= 0) return amount;
  return amount.isEmpty ? _money(price) : '$amount × ${_money(price)}';
}

/// The select-shop modal's contents. Public so it can be laid out in tests
/// without Firestore; the app opens it through [showLineSelectionSheet].
class SelectShopSheet extends StatefulWidget {
  final List<Map<String, dynamic>> items;
  final String shopName;
  final double quotedTotal;

  const SelectShopSheet({
    super.key,
    required this.items,
    required this.shopName,
    required this.quotedTotal,
  });

  @override
  State<SelectShopSheet> createState() => _SelectShopSheetState();
}

class _SelectShopSheetState extends State<SelectShopSheet> {
  // Everything starts ticked. The builder is dropping lines, not building a
  // list from nothing, so the common case is a couple of taps.
  late final Set<int> _kept = {
    for (var i = 0; i < widget.items.length; i++) i,
  };

  late final int _substitutes =
      widget.items.where(isSubstitutedLine).length;

  bool get _lumpSum => widget.items.isEmpty;

  double get _total {
    if (_lumpSum) return widget.quotedTotal;
    var sum = 0.0;
    for (final i in _kept) {
      sum += lineTotalOf(widget.items[i]);
    }
    return sum;
  }

  void _toggle(int i) => setState(() {
        if (!_kept.remove(i)) _kept.add(i);
      });

  void _accept() {
    Navigator.pop(
      context,
      _lumpSum
          ? const LineSelectionResult(
              acceptedIndexes: null,
              acceptedTotal: 0,
              acceptedCount: 0,
              totalCount: 0,
            )
          : LineSelectionResult(
              acceptedIndexes: Set<int>.from(_kept),
              acceptedTotal: _total,
              acceptedCount: _kept.length,
              totalCount: widget.items.length,
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.9,
      ),
      decoration: const BoxDecoration(
        color: _sheetBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 10),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          _header(),
          if (_lumpSum)
            _lumpSumBody()
          else
            Flexible(child: _lineList()),
          _footer(context),
        ],
      ),
    );
  }

  Widget _header() {
    final count = widget.items.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 8, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select ${widget.shopName}',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _lumpSum
                      ? 'One price for the whole order'
                      : [
                          '$count line${count == 1 ? '' : 's'} quoted',
                          if (_substitutes > 0)
                            '$_substitutes substitute'
                                '${_substitutes == 1 ? '' : 's'}',
                        ].join(' · '),
                  style: GoogleFonts.poppins(
                    fontSize: 12.5,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Close',
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _lumpSumBody() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Text(
        '${widget.shopName} sent one price without itemised lines, so '
        'selecting them accepts the whole offer.',
        style: GoogleFonts.poppins(
          fontSize: 13,
          color: AppColors.textDark,
          height: 1.45,
        ),
      ),
    );
  }

  Widget _lineList() {
    final all = widget.items.length;
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      children: [
        if (_substitutes > 0) ...[
          _substituteNotice(),
          const SizedBox(height: 12),
        ],
        Row(
          children: [
            Expanded(
              child: Text(
                'ITEMS QUOTED',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: AppColors.textMuted,
                ),
              ),
            ),
            TextButton(
              onPressed: () => setState(() {
                if (_kept.length == all) {
                  _kept.clear();
                } else {
                  _kept.addAll({for (var i = 0; i < all; i++) i});
                }
              }),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.navySoft,
                visualDensity: VisualDensity.compact,
              ),
              child: Text(
                _kept.length == all ? 'Untick all' : 'Tick all',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        for (var i = 0; i < all; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _LineCard(
              item: widget.items[i],
              kept: _kept.contains(i),
              onTap: () => _toggle(i),
            ),
          ),
      ],
    );
  }

  Widget _substituteNotice() {
    final one = _substitutes == 1;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _subTint,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _subBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.swap_horiz_rounded, size: 18, color: _subText),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${widget.shopName} did not have ${one ? 'one' : '$_substitutes'} '
              'of your materials and offered '
              '${one ? 'a substitute' : 'substitutes'}. Check '
              '${one ? 'it' : 'them'} below, and untick any you do not want.',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: const Color(0xFF78350F),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _footer(BuildContext context) {
    final all = widget.items.length;
    final kept = _kept.length;
    final canAccept = _lumpSum || kept > 0;
    final label = _lumpSum
        ? 'Accept offer and chat'
        : kept == 0
            ? 'Tick at least one line'
            : kept == all
                ? 'Accept all and chat'
                : 'Accept $kept line${kept == 1 ? '' : 's'} and chat';

    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        14,
        20,
        14 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: _border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _lumpSum
                      ? 'Quoted total'
                      : kept == all
                          ? 'All $all lines'
                          : '$kept of $all lines',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
              Text(
                _total > 0 ? _money(_total) : '—',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: canAccept ? _accept : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.navy,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppColors.navy.withValues(alpha: 0.3),
              disabledForegroundColor: Colors.white70,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
            ),
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Opens live chat with the shop. No payment happens in the app.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

/// One quoted line, laid out like the shop dashboard's "Items quoted" list.
class _LineCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final bool kept;
  final VoidCallback onTap;

  const _LineCard({
    required this.item,
    required this.kept,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final name = quotedItemName(item);
    final substitute = isSubstitutedLine(item);
    final requested = requestedItemName(item);
    final note = quotedLineNote(item);
    final quantity = _quantityLine(item);
    final total = lineTotalOf(item);
    final fade = kept ? 1.0 : 0.45;

    return Semantics(
      checked: kept,
      child: Material(
        color: substitute ? _subTint : Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: substitute ? _subBorder : _border,
                width: substitute ? 1.4 : 1,
              ),
            ),
            child: Opacity(
              opacity: fade,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Icon(
                      kept
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      size: 22,
                      color: kept ? AppColors.navy : AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              name.isEmpty ? 'Unnamed item' : name,
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textDark,
                                decoration: kept
                                    ? null
                                    : TextDecoration.lineThrough,
                              ),
                            ),
                            if (substitute) const _SubstituteBadge(),
                          ],
                        ),
                        if (substitute && requested.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              'instead of $requested',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: _subText,
                              ),
                            ),
                          ),
                        if (quantity.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              quantity,
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ),
                        if (note.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '“$note”',
                              style: GoogleFonts.poppins(
                                fontSize: 11.5,
                                fontStyle: FontStyle.italic,
                                color: AppColors.textMuted,
                                height: 1.35,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    total > 0 ? _money(total) : 'No price',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: total > 0
                          ? AppColors.textDark
                          : AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SubstituteBadge extends StatelessWidget {
  const _SubstituteBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _subBorder),
      ),
      child: Text(
        'SUBSTITUTE',
        style: GoogleFonts.poppins(
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          color: _subText,
        ),
      ),
    );
  }
}
