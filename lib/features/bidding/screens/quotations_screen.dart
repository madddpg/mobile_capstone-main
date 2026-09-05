import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:iconstruct/features/bidding/data/bid_comparison.dart';
import 'package:iconstruct/features/bidding/screens/project_bids_screen.dart';
import 'package:iconstruct/core/widgets/app_message.dart';

class QuotationsScreen extends StatefulWidget {
  final String postId;

  /// Shown on the full-details screen; resolved from the post when omitted.
  final String? projectName;

  const QuotationsScreen({super.key, required this.postId, this.projectName});

  static const Color bgCream = Color(0xFFF9F6F0);
  static const Color navyColor = Color(0xFF1E2A38);

  @override
  State<QuotationsScreen> createState() => _QuotationsScreenState();
}

class _QuotationsScreenState extends State<QuotationsScreen> {
  static const int _maxShortlist = 3;
  final Set<String> _shortlistedIds = {};
  bool _canvassByMaterial = false;

  Future<void> _openFullDetails(BuildContext context) async {
    var name = widget.projectName ?? '';

    if (name.isEmpty) {
      try {
        final snap = await FirebaseFirestore.instance
            .collection('projectPosts')
            .doc(widget.postId)
            .get();
        name = (snap.data()?['projectName'] ?? '').toString();
      } catch (_) {
        // Fall back to a generic title below.
      }
    }

    if (!context.mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProjectBidsScreen(
          postId: widget.postId,
          projectName: name.isEmpty ? 'Project' : name,
        ),
      ),
    );
  }

  String _money(double amount) => formatBidMoney(amount);

  void _toggleShortlist(String quoteId) {
    setState(() {
      if (_shortlistedIds.contains(quoteId)) {
        _shortlistedIds.remove(quoteId);
        return;
      }
      if (_shortlistedIds.length >= _maxShortlist) {
        showAppMessage(context, 
          const SnackBar(
            content: Text('Shortlist up to 3 shops to compare.'),
          ),
        );
        return;
      }
      _shortlistedIds.add(quoteId);
    });
  }

  void _openCompare(List<BidQuote> allQuotes) {
    final shortlisted = allQuotes
        .where((q) => _shortlistedIds.contains(q.id))
        .toList();
    if (shortlisted.length < 2) return;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: QuotationsScreen.bgCream,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) {
        final comparison = BidComparison.fromQuotes(shortlisted);
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.72,
          minChildSize: 0.45,
          maxChildSize: 0.92,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Shortlist compare',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: QuotationsScreen.navyColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Side-by-side look at your pinned shops.',
                    style: GoogleFonts.poppins(
                      fontSize: 12.5,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (final line in comparison.summaryLines())
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '• $line',
                        style: GoogleFonts.poppins(
                          fontSize: 12.5,
                          color: QuotationsScreen.navyColor,
                          height: 1.35,
                        ),
                      ),
                    ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: ListView.separated(
                      controller: scrollController,
                      itemCount: shortlisted.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final quote = shortlisted[index];
                        final tags = comparison.highlightsFor(quote.id);
                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: QuotationsScreen.navyColor
                                  .withValues(alpha: 0.12),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      quote.shopName,
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                        color: QuotationsScreen.navyColor,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    _money(quote.allInTotal),
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16,
                                      color: tags.contains(
                                            BidHighlight.lowestTotal,
                                          )
                                          ? const Color(0xFF2E7D32)
                                          : QuotationsScreen.navyColor,
                                    ),
                                  ),
                                ],
                              ),
                              if (tags.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: [
                                    for (final tag in tags)
                                      _HighlightChip(tag: tag),
                                  ],
                                ),
                              ],
                              const SizedBox(height: 10),
                              Text(
                                'Materials: ${quote.materialsCovered}  ·  '
                                'Lead: ${quote.leadTimeRaw.isEmpty ? 'N/A' : quote.leadTimeRaw}  ·  '
                                'Delivery: ${quote.deliveryFee > 0 ? _money(quote.deliveryFee) : '—'}',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: Colors.black54,
                                  height: 1.35,
                                ),
                              ),
                              const SizedBox(height: 10),
                              _QuoteLineItems(quote: quote),
                              const SizedBox(height: 10),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    _openFullDetails(context);
                                  },
                                  child: Text(
                                    'Open full details',
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: QuotationsScreen.bgCream,
      appBar: AppBar(
        backgroundColor: QuotationsScreen.bgCream,
        elevation: 0,
        iconTheme: const IconThemeData(color: QuotationsScreen.navyColor),
        title: Text(
          'Shop Quotations',
          style: GoogleFonts.poppins(
            color: QuotationsScreen.navyColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('projectPosts')
            .doc(widget.postId)
            .snapshots(),
        builder: (context, postSnap) {
          final postData =
              postSnap.data?.data() as Map<String, dynamic>? ?? {};
          final bom = parseQuotedLines(postData);

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('projectPosts')
                .doc(widget.postId)
                .collection('quotations')
                .orderBy('estimatedTotal', descending: false)
                .snapshots(),
            builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(
                color: QuotationsScreen.navyColor,
              ),
            );
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.inventory_2_outlined,
                      size: 80,
                      color: QuotationsScreen.navyColor.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No quotations yet',
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: QuotationsScreen.navyColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Hardware shops will appear here once they submit bids for your posted estimate. Only you see these quotes.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        color: Colors.black54,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final quotes = docs
              .map(
                (doc) => BidQuote.fromMap(
                  doc.id,
                  doc.data() as Map<String, dynamic>,
                ),
              )
              .toList();
          final comparison = BidComparison.fromQuotes(quotes);
          final advice = canvassAdvice(bom, quotes);
          final summary = [
            if (advice.headline.isNotEmpty) advice.headline,
            if (advice.detail.isNotEmpty) advice.detail,
            ...comparison.summaryLines().skip(quotes.length > 1 ? 1 : 0),
          ];
          final canCompare = _shortlistedIds.length >= 2;

          return Column(
            children: [
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  itemCount: _canvassByMaterial
                      ? 1 + (bom.isEmpty ? 1 : bom.length)
                      : quotes.length + 1,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _BidSummaryCard(
                            lines: summary,
                            quoteCount: quotes.length,
                          ),
                          if (quotes.length > 1 && !_canvassByMaterial) ...[
                            const SizedBox(height: 10),
                            Text(
                              'Pin up to 3 shops, then compare side by side.',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                          if (bom.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            _CanvassModeToggle(
                              byMaterial: _canvassByMaterial,
                              onChanged: (value) {
                                setState(() => _canvassByMaterial = value);
                              },
                            ),
                            if (_canvassByMaterial) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Compare each shop’s offered price for the same item.',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ],
                        ],
                      );
                    }

                    if (_canvassByMaterial) {
                      if (bom.isEmpty) {
                        return Text(
                          'This estimate has no material list to canvass yet.',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: Colors.black54,
                          ),
                        );
                      }
                      return _MaterialCanvassCard(
                        item: bom[index - 1],
                        quotes: quotes,
                      );
                    }

                    final quote = quotes[index - 1];
                    final tags = comparison.highlightsFor(quote.id);
                    final isStandout = tags.isNotEmpty;
                    final pinned = _shortlistedIds.contains(quote.id);

                    return Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: pinned
                            ? Border.all(
                                color: const Color(0xFF2C3E50),
                                width: 1.8,
                              )
                            : isStandout
                                ? Border.all(
                                    color: const Color(0xFF2C3E50)
                                        .withValues(alpha: 0.35),
                                    width: 1.5,
                                  )
                                : null,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (tags.isNotEmpty)
                                Expanded(
                                  child: Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: [
                                      for (final tag in tags)
                                        _HighlightChip(tag: tag),
                                    ],
                                  ),
                                )
                              else
                                const Spacer(),
                              IconButton(
                                tooltip: pinned
                                    ? 'Remove from shortlist'
                                    : 'Add to shortlist',
                                onPressed: () => _toggleShortlist(quote.id),
                                icon: Icon(
                                  pinned
                                      ? Icons.push_pin
                                      : Icons.push_pin_outlined,
                                  color: pinned
                                      ? QuotationsScreen.navyColor
                                      : Colors.black45,
                                ),
                              ),
                            ],
                          ),
                          if (tags.isNotEmpty) const SizedBox(height: 4),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  quote.shopName,
                                  style: GoogleFonts.poppins(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color: QuotationsScreen.navyColor,
                                  ),
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    _money(quote.estimatedTotal),
                                    style: GoogleFonts.poppins(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      color: tags.contains(
                                            BidHighlight.lowestTotal,
                                          )
                                          ? const Color(0xFF2E7D32)
                                          : QuotationsScreen.navyColor,
                                    ),
                                  ),
                                  if (quote.deliveryFee > 0)
                                    Text(
                                      'All-in ${_money(quote.allInTotal)}',
                                      style: GoogleFonts.poppins(
                                        fontSize: 11,
                                        color: Colors.black54,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                          if (quote.message.trim().isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              quote.message,
                              style: GoogleFonts.poppins(
                                color: Colors.black54,
                                height: 1.4,
                                fontSize: 13,
                              ),
                            ),
                          ],
                          const SizedBox(height: 14),
                          const Divider(height: 1),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _buildSubDetail(
                                  Icons.local_shipping_outlined,
                                  quote.deliveryFee > 0
                                      ? 'Fee: ${_money(quote.deliveryFee)}'
                                      : 'Fee: —',
                                ),
                              ),
                              Expanded(
                                child: _buildSubDetail(
                                  Icons.timer_outlined,
                                  quote.leadTimeRaw.isEmpty
                                      ? 'Lead: N/A'
                                      : quote.leadTimeRaw,
                                ),
                              ),
                            ],
                          ),
                          if (quote.materialsCovered > 0) ...[
                            const SizedBox(height: 8),
                            _buildSubDetail(
                              Icons.inventory_2_outlined,
                              '${quote.materialsCovered} material'
                              '${quote.materialsCovered == 1 ? '' : 's'} listed',
                            ),
                          ],
                          const SizedBox(height: 12),
                          _QuoteLineItems(quote: quote),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            child: TextButton(
                              onPressed: () => _openFullDetails(context),
                              style: TextButton.styleFrom(
                                foregroundColor: QuotationsScreen.navyColor,
                                backgroundColor: QuotationsScreen.bgCream,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: Text(
                                'View full details',
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              if (quotes.length > 1)
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed:
                            canCompare ? () => _openCompare(quotes) : null,
                        icon: const Icon(Icons.compare_arrows_rounded),
                        label: Text(
                          canCompare
                              ? 'Compare shortlist (${_shortlistedIds.length})'
                              : 'Pin 2–3 shops to compare',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: QuotationsScreen.navyColor,
                          foregroundColor: const Color(0xFFEDE4D4),
                          disabledBackgroundColor:
                              QuotationsScreen.navyColor.withValues(alpha: 0.35),
                          disabledForegroundColor:
                              const Color(0xFFEDE4D4).withValues(alpha: 0.7),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
            },
          );
        },
      ),
    );
  }

  Widget _buildSubDetail(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.black45),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            style: GoogleFonts.poppins(
              color: Colors.black87,
              fontWeight: FontWeight.w500,
              fontSize: 12.5,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _CanvassModeToggle extends StatelessWidget {
  final bool byMaterial;
  final ValueChanged<bool> onChanged;

  const _CanvassModeToggle({
    required this.byMaterial,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _modeChip(
            label: 'By shop',
            selected: !byMaterial,
            onTap: () => onChanged(false),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _modeChip(
            label: 'By material',
            selected: byMaterial,
            onTap: () => onChanged(true),
          ),
        ),
      ],
    );
  }

  Widget _modeChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: selected ? QuotationsScreen.navyColor : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: selected
                    ? const Color(0xFFEDE4D4)
                    : QuotationsScreen.navyColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _QuoteLineItems extends StatelessWidget {
  final BidQuote quote;

  const _QuoteLineItems({required this.quote});

  @override
  Widget build(BuildContext context) {
    if (quote.lines.isEmpty) {
      return Text(
        'This shop sent a lump total only — item prices were not listed.',
        style: GoogleFonts.poppins(
          fontSize: 12,
          color: Colors.black54,
          height: 1.35,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Item prices',
          style: GoogleFonts.poppins(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: QuotationsScreen.navyColor,
          ),
        ),
        const SizedBox(height: 8),
        for (final line in quote.lines)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        line.name,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: QuotationsScreen.navyColor,
                        ),
                      ),
                      if (line.quantityLabel.isNotEmpty ||
                          line.size.trim().isNotEmpty)
                        Text(
                          [
                            if (line.quantityLabel.isNotEmpty) line.quantityLabel,
                            if (line.size.trim().isNotEmpty)
                              'Size: ${line.size}',
                          ].join(' · '),
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: Colors.black54,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      line.hasPrice
                          ? _unitPriceLabel(line)
                          : 'No item price',
                      style: GoogleFonts.poppins(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: line.hasPrice
                            ? QuotationsScreen.navyColor
                            : Colors.black45,
                      ),
                    ),
                    if (line.hasPrice && line.lineTotal > 0)
                      Text(
                        formatBidMoney(line.lineTotal),
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF2E7D32),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }

  String _unitPriceLabel(QuotedLine line) {
    if (line.unitPrice <= 0) return formatBidMoney(line.lineTotal);
    final unit = line.unit.trim();
    if (unit.isEmpty) return formatBidMoney(line.unitPrice);
    return '${formatBidMoney(line.unitPrice)} / $unit';
  }
}

class _MaterialCanvassCard extends StatelessWidget {
  final QuotedLine item;
  final List<BidQuote> quotes;

  const _MaterialCanvassCard({
    required this.item,
    required this.quotes,
  });

  @override
  Widget build(BuildContext context) {
    final lowest = lowestPricedShopFor(quotes, item.name);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.name,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: QuotationsScreen.navyColor,
            ),
          ),
          if (item.quantityLabel.isNotEmpty || item.size.trim().isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              [
                if (item.quantityLabel.isNotEmpty) item.quantityLabel,
                if (item.size.trim().isNotEmpty) 'Size: ${item.size}',
              ].join(' · '),
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.black54,
              ),
            ),
          ],
          const SizedBox(height: 12),
          for (final quote in quotes)
            _shopOfferRow(
              quote: quote,
              line: findQuotedLine(quote.lines, item.name),
              isLowest: lowest?.id == quote.id,
            ),
        ],
      ),
    );
  }

  Widget _shopOfferRow({
    required BidQuote quote,
    required QuotedLine? line,
    required bool isLowest,
  }) {
    final hasPrice = line?.hasPrice == true;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  quote.shopName,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: QuotationsScreen.navyColor,
                  ),
                ),
                if (isLowest && hasPrice)
                  Text(
                    'Lowest for this item',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF2E7D32),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                hasPrice
                    ? _unitPriceLabel(line!)
                    : (line != null
                          ? 'Listed, no price'
                          : 'Not quoted'),
                style: GoogleFonts.poppins(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: hasPrice
                      ? (isLowest
                            ? const Color(0xFF2E7D32)
                            : QuotationsScreen.navyColor)
                      : Colors.black45,
                ),
              ),
              if (hasPrice && line!.lineTotal > 0)
                Text(
                  formatBidMoney(line.lineTotal),
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isLowest
                        ? const Color(0xFF2E7D32)
                        : Colors.black54,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _unitPriceLabel(QuotedLine line) {
    if (line.unitPrice <= 0) return formatBidMoney(line.lineTotal);
    final unit = line.unit.trim();
    if (unit.isEmpty) return formatBidMoney(line.unitPrice);
    return '${formatBidMoney(line.unitPrice)} / $unit';
  }
}

class _BidSummaryCard extends StatelessWidget {
  final List<String> lines;
  final int quoteCount;

  const _BidSummaryCard({required this.lines, required this.quoteCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E3042),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.analytics_outlined,
                color: Color(0xFFEDE4D4),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                quoteCount <= 1 ? 'Quote snapshot' : 'Automatic bid summary',
                style: GoogleFonts.poppins(
                  color: const Color(0xFFEDE4D4),
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final line in lines) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '•  ',
                    style: GoogleFonts.poppins(
                      color: const Color(0xFFEDE4D4),
                      height: 1.35,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      line,
                      style: GoogleFonts.poppins(
                        color: const Color(0xFFEDE4D4).withValues(alpha: 0.92),
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (quoteCount > 1)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Pin shops to shortlist, then compare before accepting.',
                style: GoogleFonts.poppins(
                  color: const Color(0xFFEDE4D4).withValues(alpha: 0.7),
                  fontSize: 11.5,
                  height: 1.3,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _HighlightChip extends StatelessWidget {
  final BidHighlight tag;

  const _HighlightChip({required this.tag});

  @override
  Widget build(BuildContext context) {
    final (:label, :bg, :fg) = switch (tag) {
      BidHighlight.lowestTotal => (
          label: 'Lowest total',
          bg: const Color(0xFFD1FAE5),
          fg: const Color(0xFF065F46),
        ),
      BidHighlight.fastestLead => (
          label: 'Fastest lead',
          bg: const Color(0xFFDBEAFE),
          fg: const Color(0xFF1E3A8A),
        ),
      BidHighlight.mostComplete => (
          label: 'Most complete',
          bg: const Color(0xFFFEF3C7),
          fg: const Color(0xFF92400E),
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}
