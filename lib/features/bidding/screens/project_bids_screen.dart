import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'package:iconstruct/core/firebase/firestore_error.dart';
import 'package:iconstruct/core/state/user_state/user_provider.dart';
import 'package:iconstruct/core/theme/app_theme.dart';
import 'package:iconstruct/core/widgets/app_message.dart';
import 'package:iconstruct/core/widgets/iconstruct_panel.dart';
import 'package:iconstruct/core/widgets/offset_panel_shell.dart';
import 'package:iconstruct/features/bidding/data/bid_comparison.dart';
import 'package:iconstruct/features/bidding/data/quotation_accept_service.dart';
import 'package:iconstruct/features/bidding/widgets/line_selection_sheet.dart';
import 'package:iconstruct/features/chat/data/chat_service.dart';
import 'package:iconstruct/features/chat/screens/chat_thread_screen.dart';

class ProjectBidsScreen extends StatelessWidget {
  final String postId;
  final String projectName;

  const ProjectBidsScreen({
    super.key,
    required this.postId,
    required this.projectName,
  });

  @override
  Widget build(BuildContext context) {
    return OffsetPanelShell(
      extent: OffsetPanelExtent.fillBottom,
      safeAreaBottom: false,
      activeNav: OffsetNavTab.bidding,
      panelColor: IConstructPanel.darkBlue,
      contentPadding: EdgeInsets.zero,
      header: OffsetPanelHeaders.backOnly(context),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('projectPosts')
            .doc(postId)
            .snapshots(),
        builder: (context, projectSnapshot) {
          if (projectSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.cream),
            );
          }

          if (projectSnapshot.hasError ||
              !projectSnapshot.hasData ||
              !projectSnapshot.data!.exists) {
            return _PanelMessage('Could not load this estimate.');
          }

          final projectData =
              projectSnapshot.data!.data() as Map<String, dynamic>? ?? {};
          final bom = parseQuotedLines({'materials': projectData['materials']});
          // Treat an empty string as "no supplier selected" — the web side can
          // write `''`, and `'' != null` would otherwise hide every Accept
          // button and leave the screen unrecoverable.
          final rawSelected =
              projectData['selectedQuotationId']?.toString().trim() ?? '';
          final selectedQuotationId = rawSelected.isEmpty ? null : rawSelected;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Text(
                  projectName,
                  style: GoogleFonts.poppins(
                    color: AppColors.cream,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                    letterSpacing: -0.4,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Text(
                  'Compare quotations',
                  style: GoogleFonts.poppins(
                    color: AppColors.cream.withValues(alpha: 0.72),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Container(
                  height: 1,
                  color: AppColors.cream.withValues(alpha: 0.35),
                ),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('projectPosts')
                      .doc(postId)
                      .collection('quotations')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(color: AppColors.cream),
                      );
                    }
                    if (snapshot.hasError) {
                      return const _PanelMessage(
                        'Could not load quotations.',
                      );
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const _PanelMessage('No quotations yet.');
                    }

                    final shops = snapshot.data!.docs.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return _ShopOffer(
                        quote: BidQuote.fromMap(doc.id, data),
                        status: (data['status'] ?? 'pending').toString(),
                        shopId: quotationShopId(data, doc.id),
                      );
                    }).toList();

                    final quotes = shops.map((s) => s.quote).toList();
                    final comparison = BidComparison.fromQuotes(quotes);
                    final advice = canvassAdvice(bom, quotes);
                    final materials = materialsToCompare(bom, quotes);
                    shops.sort((a, b) {
                      final aSuggested = a.quote.id == advice.suggestedShopId;
                      final bSuggested = b.quote.id == advice.suggestedShopId;
                      if (aSuggested != bSuggested) return aSuggested ? -1 : 1;
                      final cov = bomCoverageCount(bom, b.quote)
                          .compareTo(bomCoverageCount(bom, a.quote));
                      if (cov != 0) return cov;
                      return a.quote.allInTotal.compareTo(b.quote.allInTotal);
                    });

                    return ListView(
                      padding: const EdgeInsets.fromLTRB(20, 16, 18, 28),
                      children: [
                        if (advice.headline.isNotEmpty) ...[
                          _SmartAdviceCard(advice: advice),
                          const SizedBox(height: 12),
                        ],
                        _InsightStrip(
                          comparison: comparison,
                          bom: bom,
                          shops: shops,
                        ),
                        const SizedBox(height: 16),
                        _SectionLabel('Shops'),
                        const SizedBox(height: 10),
                        for (final shop in shops) ...[
                          _ShopSummaryCard(
                            shop: shop,
                            bom: bom,
                            tags: comparison.highlightsFor(shop.quote.id),
                            isSuggested:
                                shop.quote.id == advice.suggestedShopId &&
                                quotes.length > 1,
                            isSelected: selectedQuotationId == shop.quote.id,
                            hasAcceptedOffer: selectedQuotationId != null,
                            onAccept: () => _confirmAccept(context, shop),
                            onMessage: () => _openShopChat(context, shop),
                          ),
                          const SizedBox(height: 12),
                        ],
                        const SizedBox(height: 6),
                        _SectionLabel('Materials'),
                        const SizedBox(height: 6),
                        Text(
                          'Compare each shop on the same row. A skipped item is not filled in from another bid.',
                          style: GoogleFonts.poppins(
                            color: AppColors.cream.withValues(alpha: 0.7),
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (materials.isEmpty)
                          const _CreamCard(
                            child: Text(
                              'No item list to compare yet. Shop totals are still shown above.',
                            ),
                          )
                        else
                          for (final item in materials) ...[
                            _MaterialCompareCard(item: item, shops: shops),
                            const SizedBox(height: 12),
                          ],
                        ..._extraCards(shops, bom),
                      ],
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _extraCards(List<_ShopOffer> shops, List<QuotedLine> bom) {
    final cards = <Widget>[];
    for (final shop in shops) {
      final lines = extraQuotedLines(bom, shop.quote)
          .where((line) => line.hasPrice)
          .toList();
      if (lines.isEmpty) continue;
      cards.add(
        _CreamCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Also quoted by ${shop.quote.shopName}',
                style: GoogleFonts.poppins(
                  color: AppColors.textDark,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Not on your estimate list.',
                style: GoogleFonts.poppins(
                  color: AppColors.textMuted,
                  fontSize: 11.5,
                ),
              ),
              const SizedBox(height: 10),
              for (final line in lines)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          line.name,
                          style: GoogleFonts.poppins(
                            color: AppColors.textDark,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      Text(
                        formatBidMoney(line.lineTotal),
                        style: GoogleFonts.poppins(
                          color: AppColors.success,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      );
      cards.add(const SizedBox(height: 12));
    }
    return cards;
  }

  Future<void> _confirmAccept(BuildContext context, _ShopOffer shop) async {
    // Per-line choice. A builder canvassing several shops usually wants
    // cement from one and tile from another, so an offer can be taken in part.
    final selection = await showLineSelectionSheet(
      context,
      postId: postId,
      quotationId: shop.quote.id,
      shopName: shop.quote.shopName,
    );

    if (selection == null || !context.mounted) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: AppColors.cream),
      ),
    );

    try {
      await QuotationAcceptService().acceptQuotation(
        postId: postId,
        quotationId: shop.quote.id,
        shopId: shop.shopId,
        shopName: shop.quote.shopName,
        acceptedIndexes: selection.acceptedIndexes,
      );
    } catch (e) {
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      final message = e is FirebaseException
          ? firestoreUserMessage(e, action: 'select this shop')
          : e.toString().replaceFirst(RegExp(r'^Exception: '), '');
      showAppMessage(
        context,
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
      return;
    }

    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    await _openShopChat(context, shop);
  }

  Future<void> _openShopChat(BuildContext context, _ShopOffer shop) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: AppColors.cream),
      ),
    );

    try {
      final builderName =
          context.read<UserProvider>().currentUser?.fullName.trim();
      final title = projectName.isEmpty ? 'Estimate' : projectName;
      final conversationId = await ChatService().ensureConversationAfterAccept(
        projectId: postId,
        shopId: shop.shopId,
        quotationId: shop.quote.id,
        projectTitle: title,
        shopName: shop.quote.shopName,
        builderName: (builderName == null || builderName.isEmpty)
            ? 'Builder'
            : builderName,
      );

      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatThreadScreen(
            conversationId: conversationId,
            shopName: shop.quote.shopName,
            postId: postId,
            shopId: shop.shopId,
            quotationId: shop.quote.id,
            projectTitle: title,
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      final message = e is FirebaseException
          ? firestoreUserMessage(e, action: 'load this conversation')
          : e.toString().replaceFirst(RegExp(r'^Exception: '), '');
      showAppMessage(
        context,
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }
}

class _ShopOffer {
  final BidQuote quote;
  final String status;
  final String shopId;

  const _ShopOffer({
    required this.quote,
    required this.status,
    required this.shopId,
  });
}

class _PanelMessage extends StatelessWidget {
  final String text;

  const _PanelMessage(this.text);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            color: AppColors.cream.withValues(alpha: 0.85),
            fontSize: 15,
            height: 1.4,
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: GoogleFonts.poppins(
        color: AppColors.cream.withValues(alpha: 0.55),
        fontWeight: FontWeight.w700,
        fontSize: 11,
        letterSpacing: 1.2,
      ),
    );
  }
}

class _CreamCard extends StatelessWidget {
  final Widget child;
  final Color? borderColor;

  const _CreamCard({
    required this.child,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(24),
        border: borderColor == null
            ? null
            : Border.all(color: borderColor!, width: 2.4),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: DefaultTextStyle(
        style: GoogleFonts.poppins(
          color: AppColors.textDark,
          fontSize: 13,
          height: 1.35,
        ),
        child: child,
      ),
    );
  }
}

class _SmartAdviceCard extends StatelessWidget {
  final CanvassAdvice advice;

  const _SmartAdviceCard({required this.advice});

  @override
  Widget build(BuildContext context) {
    return _CreamCard(
      borderColor: IConstructPanel.midBlue,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.auto_awesome_rounded,
                size: 18,
                color: AppColors.navySoft,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  advice.headline,
                  style: GoogleFonts.poppins(
                    color: AppColors.textDark,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    height: 1.25,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            advice.detail,
            style: GoogleFonts.poppins(
              color: AppColors.textDark.withValues(alpha: 0.82),
              fontSize: 12.5,
              height: 1.4,
            ),
          ),
          if (advice.gaps.isNotEmpty) ...[
            const SizedBox(height: 12),
            for (final gap in advice.gaps)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(
                        Icons.swap_horiz_rounded,
                        size: 16,
                        color: AppColors.warning,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${gap.materialName}: ${gap.missingFromShop} did not bid. '
                        '${gap.quotedByShop} quoted ${formatBidMoney(gap.referenceTotal)}.',
                        style: GoogleFonts.poppins(
                          color: AppColors.textDark,
                          fontSize: 12,
                          height: 1.35,
                          fontWeight: FontWeight.w600,
                        ),
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
}

class _InsightStrip extends StatelessWidget {
  final BidComparison comparison;
  final List<QuotedLine> bom;
  final List<_ShopOffer> shops;

  const _InsightStrip({
    required this.comparison,
    required this.bom,
    required this.shops,
  });

  @override
  Widget build(BuildContext context) {
    final quotes = shops.map((s) => s.quote).toList();
    BidQuote? byId(String? id) {
      if (id == null) return null;
      for (final q in quotes) {
        if (q.id == id) return q;
      }
      return null;
    }

    final cheapest = byId(comparison.lowestTotalId);
    final fullest = byId(comparison.mostCompleteId);
    final gapNames = <String>{};
    if (bom.isNotEmpty) {
      for (final shop in shops) {
        for (final item in unquotedBomItems(bom, shop.quote)) {
          if (lowestPricedShopFor(quotes, item.name) != null) {
            gapNames.add(item.name);
          }
        }
      }
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _InsightChip(
          icon: Icons.storefront_outlined,
          label: '${shops.length} shop${shops.length == 1 ? '' : 's'}',
        ),
        if (cheapest != null)
          _InsightChip(
            icon: Icons.payments_outlined,
            label: 'Lowest ${cheapest.shopName}',
            tint: const Color(0xFFD1FAE5),
            fg: const Color(0xFF065F46),
          ),
        if (fullest != null && shops.length > 1)
          _InsightChip(
            icon: Icons.inventory_2_outlined,
            label: 'Most complete ${fullest.shopName}',
            tint: const Color(0xFFFEF3C7),
            fg: const Color(0xFF92400E),
          ),
        if (gapNames.isNotEmpty)
          _InsightChip(
            icon: Icons.flag_outlined,
            label: gapNames.length == 1
                ? '${gapNames.first} quoted elsewhere'
                : '${gapNames.length} items quoted elsewhere',
            tint: const Color(0xFFFFEDD5),
            fg: const Color(0xFF9A3412),
          ),
      ],
    );
  }
}

class _InsightChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color tint;
  final Color fg;

  const _InsightChip({
    required this.icon,
    required this.label,
    this.tint = const Color(0xFFE8DCC8),
    this.fg = AppColors.navySoft,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 180),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                color: fg,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShopSummaryCard extends StatelessWidget {
  final _ShopOffer shop;
  final List<QuotedLine> bom;
  final Set<BidHighlight> tags;
  final bool isSuggested;
  final bool isSelected;
  final bool hasAcceptedOffer;
  final VoidCallback onAccept;
  final VoidCallback onMessage;

  const _ShopSummaryCard({
    required this.shop,
    required this.bom,
    required this.tags,
    required this.isSuggested,
    required this.isSelected,
    required this.hasAcceptedOffer,
    required this.onAccept,
    required this.onMessage,
  });

  @override
  Widget build(BuildContext context) {
    final covered = bomCoverageCount(bom, shop.quote);
    final totalItems = bom.isEmpty ? shop.quote.lines.length : bom.length;
    final missing = unquotedBomItems(bom, shop.quote);
    final isLowest = tags.contains(BidHighlight.lowestTotal);
    final canAccept =
        !hasAcceptedOffer &&
        (shop.status.toLowerCase() == 'pending' ||
            shop.status.toLowerCase() == 'submitted');
    final coverage = totalItems == 0 ? 0.0 : covered / totalItems;

    return _CreamCard(
      borderColor: isSelected
          ? AppColors.success
          : isSuggested
          ? IConstructPanel.midBlue
          : isLowest
          ? IConstructPanel.midBlue.withValues(alpha: 0.45)
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Shop',
                style: GoogleFonts.poppins(
                  color: AppColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.4,
                ),
              ),
              const Spacer(),
              _StatusBadge(status: shop.status),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  shop.quote.shopName,
                  style: GoogleFonts.poppins(
                    color: AppColors.textDark,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    height: 1.15,
                  ),
                ),
              ),
              Text(
                formatBidMoney(shop.quote.estimatedTotal),
                style: GoogleFonts.poppins(
                  color: isLowest ? AppColors.success : AppColors.textDark,
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                ),
              ),
            ],
          ),
          if (shop.quote.deliveryFee > 0) ...[
            const SizedBox(height: 2),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'All-in ${formatBidMoney(shop.quote.allInTotal)}',
                style: GoogleFonts.poppins(
                  color: AppColors.textMuted,
                  fontSize: 11,
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: coverage,
                    minHeight: 8,
                    backgroundColor: AppColors.navy.withValues(alpha: 0.10),
                    color: coverage >= 1
                        ? IConstructPanel.midBlue
                        : AppColors.warning,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                totalItems == 0
                    ? 'Lump total'
                    : '$covered/$totalItems',
                style: GoogleFonts.poppins(
                  color: coverage < 1 && totalItems > 0
                      ? AppColors.warning
                      : AppColors.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          if (missing.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'No quote: ${missing.map((m) => m.name).join(', ')}',
              style: GoogleFonts.poppins(
                color: AppColors.textMuted,
                fontSize: 11.5,
                height: 1.3,
              ),
            ),
          ],
          if (isSuggested) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFDBEAFE),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Suggested for this list',
                style: GoogleFonts.poppins(
                  color: const Color(0xFF1E3A8A),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
          if (tags.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [for (final tag in tags) _HighlightPill(tag: tag)],
            ),
          ],
          const SizedBox(height: 14),
          if (canAccept)
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                onPressed: onAccept,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.navySoft,
                  foregroundColor: AppColors.cream,
                  elevation: 0,
                  shape: const StadiumBorder(),
                ),
                child: Text(
                  'Select shop',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
                ),
              ),
            )
          else if (isSelected) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 11),
              decoration: BoxDecoration(
                color: const Color(0xFFD1FAE5),
                borderRadius: BorderRadius.circular(99),
              ),
              child: Center(
                child: Text(
                  'Selected supplier',
                  style: GoogleFonts.poppins(
                    color: const Color(0xFF065F46),
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                onPressed: onMessage,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.navySoft,
                  foregroundColor: AppColors.cream,
                  elevation: 0,
                  shape: const StadiumBorder(),
                ),
                child: Text(
                  'Message shop',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MaterialCompareCard extends StatelessWidget {
  final QuotedLine item;
  final List<_ShopOffer> shops;

  const _MaterialCompareCard({
    required this.item,
    required this.shops,
  });

  @override
  Widget build(BuildContext context) {
    final quotes = shops.map((s) => s.quote).toList();
    final lowest = lowestPricedShopFor(quotes, item.name);
    final priced = <double>[];
    for (final shop in shops) {
      final line = findQuotedLine(shop.quote.lines, item.name);
      if (line != null && line.hasPrice) {
        priced.add(quotedComparePrice(line));
      }
    }
    final bestPrice = priced.isEmpty
        ? 0.0
        : priced.reduce((a, b) => a < b ? a : b);
    final quotedCount = priced.length;

    return _CreamCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Material',
            style: GoogleFonts.poppins(
              color: AppColors.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            item.name,
            style: GoogleFonts.poppins(
              color: AppColors.textDark,
              fontWeight: FontWeight.w800,
              fontSize: 16,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            [
              if (item.quantityLabel.isNotEmpty) item.quantityLabel,
              if (item.size.trim().isNotEmpty) 'Size: ${item.size}',
              '$quotedCount of ${shops.length} quoted',
            ].join('  ·  '),
            style: GoogleFonts.poppins(
              color: AppColors.textMuted,
              fontSize: 11.5,
            ),
          ),
          const SizedBox(height: 12),
          for (final shop in shops)
            _ShopPriceRow(
              shop: shop,
              item: item,
              line: findQuotedLine(shop.quote.lines, item.name),
              isLowest: lowest?.id == shop.quote.id,
              bestPrice: bestPrice,
              quotedElsewhere: shops
                  .where(
                    (s) =>
                        s.quote.id != shop.quote.id &&
                        findQuotedLine(s.quote.lines, item.name)?.hasPrice ==
                            true,
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }
}

class _ShopPriceRow extends StatelessWidget {
  final _ShopOffer shop;
  final QuotedLine item;
  final QuotedLine? line;
  final bool isLowest;
  final double bestPrice;
  final List<_ShopOffer> quotedElsewhere;

  const _ShopPriceRow({
    required this.shop,
    required this.item,
    required this.line,
    required this.isLowest,
    required this.bestPrice,
    required this.quotedElsewhere,
  });

  @override
  Widget build(BuildContext context) {
    final hasPrice = line?.hasPrice == true;
    final listedWithoutPrice = line != null && !line!.hasPrice;
    final price = hasPrice ? quotedComparePrice(line!) : 0.0;
    final fill = !hasPrice || bestPrice <= 0
        ? 0.0
        : (bestPrice / price).clamp(0.18, 1.0);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  shop.quote.shopName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    color: AppColors.textDark,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
              if (hasPrice) ...[
                if (isLowest)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      'Lowest',
                      style: GoogleFonts.poppins(
                        color: AppColors.success,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ),
                Text(
                  unitPriceLabel(line!, bom: item),
                  style: GoogleFonts.poppins(
                    color: isLowest ? AppColors.success : AppColors.textDark,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ] else
                Text(
                  listedWithoutPrice ? 'Listed, no price' : 'No quote',
                  style: GoogleFonts.poppins(
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: fill,
              minHeight: 7,
              backgroundColor: AppColors.navy.withValues(alpha: 0.10),
              color: hasPrice
                  ? (isLowest ? AppColors.success : IConstructPanel.midBlue)
                  : AppColors.navy.withValues(alpha: 0.18),
            ),
          ),
          if (!hasPrice && quotedElsewhere.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              quotedElsewhere.length == 1
                  ? 'Bid by ${quotedElsewhere.first.quote.shopName}'
                  : 'Bid by ${quotedElsewhere.map((s) => s.quote.shopName).join(', ')}',
              style: GoogleFonts.poppins(
                color: AppColors.warning,
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final key = status.toLowerCase();
    final bg = key == 'accepted'
        ? const Color(0xFFD1FAE5)
        : key == 'rejected'
        ? const Color(0xFFFECACA)
        : const Color(0xFFFEF3C7);
    final fg = key == 'accepted'
        ? const Color(0xFF065F46)
        : key == 'rejected'
        ? const Color(0xFF991B1B)
        : const Color(0xFF92400E);
    final label = key == 'accepted'
        ? 'Accepted'
        : key == 'rejected'
        ? 'Rejected'
        : 'Pending';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          color: fg,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _HighlightPill extends StatelessWidget {
  final BidHighlight tag;

  const _HighlightPill({required this.tag});

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
