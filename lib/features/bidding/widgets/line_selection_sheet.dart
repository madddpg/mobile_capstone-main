import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconstruct/core/theme/app_theme.dart';
import 'package:iconstruct/core/widgets/iconstruct_panel.dart';
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
  List<Map<String, dynamic>> items;
  try {
    final snap = await FirebaseFirestore.instance
        .collection('projectPosts')
        .doc(postId)
        .collection('quotations')
        .doc(quotationId)
        .get();
    items = quotationItems(snap.data() ?? <String, dynamic>{});
  } catch (_) {
    items = const [];
  }

  if (!context.mounted) return null;

  // A shop that sent only a lump sum has nothing to tick. Fall back to a plain
  // confirmation rather than showing an empty list of choices.
  if (items.isEmpty) {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select this shop?'),
        content: Text(
          '$shopName did not send itemised lines, so this accepts their whole '
          'offer. It opens live chat with them. No payment happens in the app.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Select and chat'),
          ),
        ],
      ),
    );
    if (ok != true) return null;
    return const LineSelectionResult(
      acceptedIndexes: null,
      acceptedTotal: 0,
      acceptedCount: 0,
      totalCount: 0,
    );
  }

  if (!context.mounted) return null;

  return showModalBottomSheet<LineSelectionResult>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => _LineSelectionSheet(
      items: items,
      shopName: shopName,
    ),
  );
}

class _LineSelectionSheet extends StatefulWidget {
  final List<Map<String, dynamic>> items;
  final String shopName;

  const _LineSelectionSheet({required this.items, required this.shopName});

  @override
  State<_LineSelectionSheet> createState() => _LineSelectionSheetState();
}

class _LineSelectionSheetState extends State<_LineSelectionSheet> {
  late final Set<int> _kept;

  @override
  void initState() {
    super.initState();
    // Everything starts ticked. The builder is dropping lines, not building a
    // list from nothing, so the common case is a couple of taps.
    _kept = {for (var i = 0; i < widget.items.length; i++) i};
  }

  double get _total {
    var sum = 0.0;
    for (final i in _kept) {
      sum += lineTotalOf(widget.items[i]);
    }
    return sum;
  }

  static String _money(double v) {
    final whole = v.round().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < whole.length; i++) {
      if (i > 0 && (whole.length - i) % 3 == 0) buffer.write(',');
      buffer.write(whole[i]);
    }
    return '₱$buffer';
  }

  static String _name(Map<String, dynamic> item) {
    final n = (item['name'] ?? item['material'] ?? item['item'] ?? '')
        .toString()
        .trim();
    return n.isEmpty ? 'Unnamed item' : n;
  }

  static String _detail(Map<String, dynamic> item) {
    final parts = <String>[];
    final qty = (item['quantity'] ?? item['qty'] ?? '').toString().trim();
    final unit = (item['unit'] ?? '').toString().trim();
    final size = (item['size'] ?? '').toString().trim();
    if (qty.isNotEmpty && qty != '0') parts.add('$qty $unit'.trim());
    if (size.isNotEmpty) parts.add(size);
    return parts.join(' • ');
  }

  @override
  Widget build(BuildContext context) {
    final all = widget.items.length;
    final kept = _kept.length;
    final partial = kept < all;

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
            margin: const EdgeInsets.only(top: 10, bottom: 12),
            decoration: BoxDecoration(
              color: AppColors.cream.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Choose what to take from ${widget.shopName}',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Untick anything you would rather buy elsewhere. '
                  'You can accept part of an offer.',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: IConstructPanel.creamSoft,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
            child: Row(
              children: [
                TextButton(
                  onPressed: () => setState(() {
                    _kept
                      ..clear()
                      ..addAll({for (var i = 0; i < all; i++) i});
                  }),
                  child: Text(
                    'Select all',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppColors.cream,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => setState(_kept.clear),
                  child: Text(
                    'Clear all',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppColors.cream,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              itemCount: all,
              itemBuilder: (context, i) {
                final item = widget.items[i];
                final on = _kept.contains(i);
                final detail = _detail(item);
                final total = lineTotalOf(item);

                return CheckboxListTile(
                  value: on,
                  onChanged: (v) => setState(() {
                    if (v == true) {
                      _kept.add(i);
                    } else {
                      _kept.remove(i);
                    }
                  }),
                  dense: true,
                  controlAffinity: ListTileControlAffinity.leading,
                  activeColor: AppColors.cream,
                  checkColor: IConstructPanel.navy,
                  title: Text(
                    _name(item),
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: on ? Colors.white : Colors.white54,
                    ),
                  ),
                  subtitle: detail.isEmpty
                      ? null
                      : Text(
                          detail,
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: on
                                ? IConstructPanel.creamSoft
                                : IConstructPanel.creamSoft.withValues(alpha: 0.45),
                          ),
                        ),
                  secondary: total <= 0
                      ? null
                      : Text(
                          _money(total),
                          style: GoogleFonts.poppins(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: on ? AppColors.cream : Colors.white38,
                          ),
                        ),
                );
              },
            ),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(
              20,
              12,
              20,
              12 + MediaQuery.of(context).padding.bottom,
            ),
            decoration: BoxDecoration(
              color: IConstructPanel.darkBlue,
              border: Border(
                top: BorderSide(
                  color: AppColors.cream.withValues(alpha: 0.25),
                ),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        partial
                            ? '$kept of $all lines'
                            : 'All $all lines',
                        style: GoogleFonts.poppins(
                          fontSize: 12.5,
                          color: IConstructPanel.creamSoft,
                        ),
                      ),
                    ),
                    Text(
                      _money(_total),
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: kept == 0
                        ? null
                        : () => Navigator.pop(
                              context,
                              LineSelectionResult(
                                acceptedIndexes: Set<int>.from(_kept),
                                acceptedTotal: _total,
                                acceptedCount: kept,
                                totalCount: all,
                              ),
                            ),
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
                    child: Text(
                      kept == 0
                          ? 'Tick at least one line'
                          : partial
                              ? 'Accept $kept lines and chat'
                              : 'Accept all and chat',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
