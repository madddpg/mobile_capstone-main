import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'package:iconstruct/core/firebase/firestore_error.dart';
import 'package:iconstruct/core/state/user_state/user_provider.dart';
import 'package:iconstruct/core/theme/app_theme.dart';
import 'package:iconstruct/core/widgets/app_message.dart';
import 'package:iconstruct/core/widgets/iconstruct_panel.dart';
import 'package:iconstruct/core/widgets/offset_panel_shell.dart';
import 'package:iconstruct/features/auth/presentation/models/ranked_shop.dart';
import 'package:iconstruct/features/auth/presentation/services/shop_ranking_service.dart';
import 'package:iconstruct/features/auth/presentation/widgets/shop_rating_stars.dart';
import 'package:iconstruct/features/auth/presentation/widgets/shop_storefront_sheet.dart';
import 'package:iconstruct/features/bidding/data/bid_comparison.dart';
import 'package:iconstruct/features/bidding/data/quotation_accept_service.dart';
import 'package:iconstruct/features/bidding/data/partial_acceptance.dart';
import 'package:iconstruct/features/bidding/data/quotation_status.dart';
import 'package:iconstruct/features/bidding/data/remainder_canvass.dart';
import 'package:iconstruct/features/bidding/data/supplier_cancellation.dart';
import 'package:iconstruct/features/bidding/widgets/cancel_selection_sheet.dart';
import 'package:iconstruct/features/bidding/widgets/accepted_lines_panel.dart';
import 'package:iconstruct/features/bidding/data/post_load_outcome.dart';
import 'package:iconstruct/features/bidding/widgets/estimate_unavailable_view.dart';
import 'package:iconstruct/features/bidding/widgets/line_selection_sheet.dart';
import 'package:iconstruct/features/chat/data/chat_service.dart';
import 'package:iconstruct/features/chat/screens/chat_thread_screen.dart';

/// The builder's side-by-side view of the quotations on one posted estimate.
///
/// Each card carries only what decides a choice: who the shop is, what they
/// charge all in, and how much of the list they actually quoted. The item
/// breakdown, the lines they skipped and their storefront open in a sheet, so
/// comparing three shops is three cards rather than three screenfuls.
class ProjectBidsScreen extends StatefulWidget {
  final String postId;
  final String projectName;

  const ProjectBidsScreen({
    super.key,
    required this.postId,
    required this.projectName,
  });

  @override
  State<ProjectBidsScreen> createState() => _ProjectBidsScreenState();
}

class _ProjectBidsScreenState extends State<ProjectBidsScreen> {
  final ShopRankingService _shopDirectory = ShopRankingService();

  /// Storefronts of the shops that quoted, read once each.
  final Map<String, RankedShop> _profiles = {};
  final Set<String> _requested = {};

  String get postId => widget.postId;
  String get projectName => widget.projectName;

  // Opened once. A stream made inside build is replaced on every rebuild,
  // which drops the screen to its loading spinner and tears down the shop
  // cards — and with them the context an accept in progress needs to close
  // its spinner and open the chat.
  late final Stream<DocumentSnapshot> _postStream = FirebaseFirestore.instance
      .collection('projectPosts')
      .doc(postId)
      .snapshots();
  late final Stream<QuerySnapshot> _quotationsStream = FirebaseFirestore
      .instance
      .collection('projectPosts')
      .doc(postId)
      .collection('quotations')
      .snapshots();

  /// Reads any storefront not read yet.
  ///
  /// Called while building the list: the quotation stream rebuilds on every
  /// change, and each shop is fetched once and kept.
  void _loadProfiles(Iterable<String> shopIds) {
    final missing = <String>{
      for (final id in shopIds)
        if (id.trim().isNotEmpty && !_requested.contains(id.trim())) id.trim(),
    };
    if (missing.isEmpty) return;
    _requested.addAll(missing);
    _shopDirectory.fetchByIds(missing).then((loaded) {
      if (!mounted || loaded.isEmpty) return;
      setState(() => _profiles.addAll(loaded));
    });
  }

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
        stream: _postStream,
        builder: (context, projectSnapshot) {
          if (projectSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.cream),
            );
          }

          // One message used to cover being offline, a deleted post and a post
          // this account cannot read. They need different ways out, so the
          // screen now says which one happened.
          final outcome = classifyPostLoad(
            hasError: projectSnapshot.hasError || !projectSnapshot.hasData,
            errorCode: firestoreErrorCode(projectSnapshot.error),
            exists: projectSnapshot.data?.exists ?? false,
          );
          if (outcome != PostLoadOutcome.loaded) {
            return EstimateUnavailableView(
              outcome: outcome,
              postId: postId,
              onRetry: () => Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => ProjectBidsScreen(
                    postId: postId,
                    projectName: projectName,
                  ),
                ),
              ),
            );
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
                  bom.isEmpty
                      ? 'Compare quotations'
                      : 'Compare quotations · ${bom.length} materials requested',
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
                  stream: _quotationsStream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child:
                            CircularProgressIndicator(color: AppColors.cream),
                      );
                    }
                    if (snapshot.hasError) {
                      return const _PanelMessage('Could not load quotations.');
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const _PanelMessage('No quotations yet.');
                    }

                    final shops = snapshot.data!.docs.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final shopId = quotationShopId(data, doc.id);
                      final rawStatus = data['status']?.toString() ?? '';
                      return _ShopOffer(
                        quote: BidQuote.fromMap(doc.id, data),
                        // Acceptance is taken from this estimate, not from
                        // what the quotation says about itself.
                        status: displayQuotationStatus(
                          rawStatus: rawStatus,
                          quotationId: doc.id,
                          selectedQuotationId: selectedQuotationId,
                        ),
                        rawStatus: rawStatus,
                        shopId: shopId,
                        profile: _profiles[shopId],
                        quotationData: data,
                      );
                    }).toList();

                    _loadProfiles(shops.map((s) => s.shopId));

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
                      return a.quote.estimatedTotal.compareTo(b.quote.estimatedTotal);
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
                        _SectionLabel(
                          shops.length == 1
                              ? '1 shop quoted'
                              : '${shops.length} shops quoted',
                        ),
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
                            postId: postId,
                            remainderPostId: remainderPostIdFor(
                              projectData,
                              shop.quote.id,
                            ),
                            onAccept: () => _confirmAccept(context, shop),
                            onMessage: () => _openShopChat(
                              context,
                              shop,
                              selectedQuotationId,
                            ),
                            onCancelSelection:
                                selectedQuotationId == shop.quote.id
                                    ? () => _cancelSelection(
                                          context,
                                          shop,
                                          shops.length - 1,
                                        )
                                    : null,
                            onDetails: () => _openQuoteDetails(
                              context,
                              shop: shop,
                              bom: bom,
                              selectedQuotationId: selectedQuotationId,
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        const SizedBox(height: 6),
                        _SectionLabel('Price per material'),
                        const SizedBox(height: 6),
                        Text(
                          'Every shop on the same row. A material a shop '
                          'skipped is left blank, never filled in from another '
                          'bid.',
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
                            const SizedBox(height: 10),
                          ],
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

  Future<void> _openQuoteDetails(
    BuildContext context, {
    required _ShopOffer shop,
    required List<QuotedLine> bom,
    required String? selectedQuotationId,
  }) async {
    final action = await _showQuoteDetailsSheet(
      context,
      shop: shop,
      bom: bom,
      canAccept: selectedQuotationId == null && shop.isOpenOffer,
      isSelected: selectedQuotationId == shop.quote.id,
    );
    if (!context.mounted || action == null) return;
    switch (action) {
      case QuoteDetailAction.accept:
        await _confirmAccept(context, shop);
      case QuoteDetailAction.message:
        await _openShopChat(context, shop, selectedQuotationId);
    }
  }

  /// Cancels a selection the builder already made.
  ///
  /// Acceptance is final on purpose — the other shops were told they lost in
  /// the same transaction — so this is a recorded cancellation rather than an
  /// undo, and the Cloud Function owns the policy. See
  /// `functions/src/services/supplierSelection.js`.
  Future<void> _cancelSelection(
    BuildContext context,
    _ShopOffer shop,
    int otherQuotations,
  ) async {
    final choice = await showCancelSelectionSheet(
      context,
      shopName: shop.quote.shopName,
      otherQuotations: otherQuotations,
    );
    if (choice == null || !context.mounted) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: AppColors.cream),
      ),
    );

    try {
      final restored = await SupplierCancellationService().cancel(
        postId: postId,
        reason: choice.reason,
        note: choice.note,
      );
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      showAppMessage(
        context,
        SnackBar(
          content: Text(
            restored == 0
                ? '${shop.quote.shopName} has been told, and your estimate is '
                    'open for quotations again.'
                : '${shop.quote.shopName} has been told. '
                    '$restored quotation${restored == 1 ? '' : 's'} can be '
                    'chosen again.',
          ),
        ),
        kind: AppMessageKind.success,
      );
    } catch (e) {
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      final message = e is FirebaseFunctionsException
          ? SupplierCancellationService.friendlyError(e)
          : e.toString().replaceFirst(RegExp(r'^Exception: '), '');
      showAppMessage(
        context,
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
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
    await _openShopChat(context, shop, shop.quote.id);
  }

  Future<void> _openShopChat(
    BuildContext context,
    _ShopOffer shop,
    String? selectedQuotationId,
  ) async {
    // Read before the first await: a BuildContext must not cross one.
    final builderName =
        context.read<UserProvider>().currentUser?.fullName.trim();

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: AppColors.cream),
      ),
    );

    try {
      // Chat is gated on the quotation's own status. When this estimate says
      // the shop was selected but that write never landed, finish it here
      // rather than refusing the builder a conversation with the shop they
      // already chose.
      if (quotationNeedsStatusRepair(
        rawStatus: shop.rawStatus,
        quotationId: shop.quote.id,
        selectedQuotationId: selectedQuotationId,
      )) {
        await QuotationAcceptService().repairAcceptedStatus(
          postId: postId,
          quotationId: shop.quote.id,
        );
      }

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

/// One shop's offer on this estimate: the quotation, who sent it, and where
/// the builder's own decision left it.
class _ShopOffer {
  final BidQuote quote;

  /// Status as the builder should see it, taken from the estimate.
  final String status;

  /// Status as stored on the quotation, which the security rules read.
  final String rawStatus;
  final String shopId;

  /// The shop's storefront, once it has been read.
  final RankedShop? profile;

  /// The quotation document as stored, for reading back which lines were kept.
  final Map<String, dynamic> quotationData;

  const _ShopOffer({
    required this.quote,
    required this.status,
    required this.rawStatus,
    required this.shopId,
    required this.quotationData,
    this.profile,
  });

  bool get isOpenOffer => isOpenOfferStatus(status);
}

/// What a builder can do from the details sheet.
enum QuoteDetailAction { accept, message }

class _ShopSummaryCard extends StatelessWidget {
  final _ShopOffer shop;
  final List<QuotedLine> bom;
  final Set<BidHighlight> tags;
  final bool isSuggested;
  final bool isSelected;
  final bool hasAcceptedOffer;
  final String postId;

  /// Post id of the estimate re-canvassing the dropped lines, or empty.
  final String remainderPostId;

  final VoidCallback onAccept;
  final VoidCallback onMessage;
  final VoidCallback onDetails;

  /// Offered only on the shop the builder selected. Null elsewhere.
  final VoidCallback? onCancelSelection;

  const _ShopSummaryCard({
    required this.shop,
    required this.bom,
    required this.tags,
    required this.isSuggested,
    required this.isSelected,
    required this.hasAcceptedOffer,
    required this.postId,
    required this.remainderPostId,
    required this.onAccept,
    required this.onMessage,
    required this.onDetails,
    this.onCancelSelection,
  });

  @override
  Widget build(BuildContext context) {
    final quote = shop.quote;
    // With no material list on the estimate there is nothing to miss: every
    // line the shop sent counts as quoted.
    final covered =
        bom.isEmpty ? quote.lines.length : bomCoverageCount(bom, quote);
    final totalItems = bom.isEmpty ? quote.lines.length : bom.length;
    final missing = unquotedBomItems(bom, quote).length;
    final extras =
        extraQuotedLines(bom, quote).where((line) => line.hasPrice).length;
    final isLowest = tags.contains(BidHighlight.lowestTotal);
    final canAccept = !hasAcceptedOffer && shop.isOpenOffer;
    final coverage = totalItems == 0 ? 1.0 : covered / totalItems;
    final leadTime = quote.leadTimeRaw.trim();

    return _CreamCard(
      borderColor: isSelected
          ? AppColors.success
          : isSuggested
              ? IConstructPanel.midBlue
              : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  quote.shopName,
                  style: GoogleFonts.poppins(
                    color: AppColors.textDark,
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                    height: 1.2,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _StatusBadge(status: shop.status),
            ],
          ),
          const SizedBox(height: 6),
          _ShopIdentityLine(profile: shop.profile),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _MiniLabel('Quoted total'),
                    const SizedBox(height: 2),
                    Text(
                      formatBidMoney(quote.estimatedTotal),
                      style: GoogleFonts.poppins(
                        color: isLowest ? AppColors.success : AppColors.textDark,
                        fontWeight: FontWeight.w800,
                        fontSize: 22,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const _MiniLabel('Items quoted'),
                  const SizedBox(height: 2),
                  Text(
                    totalItems == 0 ? 'Lump sum' : '$covered of $totalItems',
                    style: GoogleFonts.poppins(
                      color: coverage < 1 ? AppColors.warning : AppColors.success,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (totalItems > 0) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: coverage,
                minHeight: 6,
                backgroundColor: AppColors.navy.withValues(alpha: 0.10),
                color:
                    coverage >= 1 ? AppColors.success : AppColors.warning,
              ),
            ),
          ],
          if (leadTime.isNotEmpty || missing > 0 || extras > 0) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (leadTime.isNotEmpty)
                  _Fact(icon: Icons.schedule_rounded, text: leadTime),
                if (missing > 0)
                  _Fact(
                    icon: Icons.remove_circle_outline_rounded,
                    text: '$missing not quoted',
                    tint: AppColors.warning,
                  ),
                if (extras > 0)
                  _Fact(
                    icon: Icons.add_circle_outline_rounded,
                    text: extras == 1 ? '1 extra item' : '$extras extra items',
                  ),
              ],
            ),
          ],
          if (isSuggested || tags.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (isSuggested)
                  const _Pill(
                    label: 'Best fit for this list',
                    bg: Color(0xFFDBEAFE),
                    fg: Color(0xFF1E3A8A),
                  ),
                for (final tag in tags) _HighlightPill(tag: tag),
              ],
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onDetails,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.navySoft,
                    side: BorderSide(
                      color: AppColors.navySoft.withValues(alpha: 0.45),
                    ),
                    minimumSize: const Size(0, 44),
                    shape: const StadiumBorder(),
                  ),
                  child: Text(
                    'Details',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              if (canAccept || isSelected) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: canAccept ? onAccept : onMessage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.navySoft,
                      foregroundColor: AppColors.cream,
                      elevation: 0,
                      minimumSize: const Size(0, 44),
                      shape: const StadiumBorder(),
                    ),
                    child: Text(
                      canAccept ? 'Select shop' : 'Message',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          // What was actually agreed, and a way to canvass the rest. The
          // status here comes from this estimate's own selection, so a
          // quotation cannot show a partial agreement the builder never made.
          if (isSelected &&
              shop.status == 'partially_accepted' &&
              readAcceptance(shop.quotationData).isPartial) ...[
            const SizedBox(height: 12),
            AcceptedLinesPanel(
              summary: readAcceptance(shop.quotationData),
              quotedTotal: shop.quote.estimatedTotal,
              postId: postId,
              quotationId: shop.quote.id,
              shopName: shop.quote.shopName,
              remainderPostId: remainderPostId.isEmpty ? null : remainderPostId,
            ),
          ],
          // A way out when the shop falls through. Deliberately quiet: it is
          // an escape hatch, not a second thought about a choice just made.
          if (isSelected && onCancelSelection != null) ...[
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onCancelSelection,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                ),
                icon: const Icon(Icons.cancel_schedule_send_outlined, size: 16),
                label: Text(
                  'Cancel this selection',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Rating, town and plan — who the shop is, in one line under their name.
class _ShopIdentityLine extends StatelessWidget {
  final RankedShop? profile;

  const _ShopIdentityLine({required this.profile});

  @override
  Widget build(BuildContext context) {
    final shop = profile;
    if (shop == null) {
      return Text(
        'Shop profile not available',
        style: GoogleFonts.poppins(
          color: AppColors.textMuted,
          fontSize: 11.5,
        ),
      );
    }

    final location = shop.shortLocation;
    final plan = shop.planLabel;

    return Wrap(
      spacing: 10,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ShopRatingStars(
          rating: shop.rating,
          size: 13,
          color: AppColors.warning,
          emptyColor: AppColors.navy.withValues(alpha: 0.25),
          textColor: AppColors.textMuted,
        ),
        if (location.isNotEmpty)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.place_outlined,
                size: 13,
                color: AppColors.textMuted,
              ),
              const SizedBox(width: 3),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 170),
                child: Text(
                  location,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    color: AppColors.textMuted,
                    fontSize: 11.5,
                  ),
                ),
              ),
            ],
          ),
        if (plan.isNotEmpty)
          _Pill(
            label: plan,
            bg: AppColors.navy.withValues(alpha: 0.08),
            fg: AppColors.navySoft,
          ),
      ],
    );
  }
}

/// The whole of one shop's offer: totals, every line, what they skipped, and
/// the storefront behind it.
Future<QuoteDetailAction?> _showQuoteDetailsSheet(
  BuildContext context, {
  required _ShopOffer shop,
  required List<QuotedLine> bom,
  required bool canAccept,
  required bool isSelected,
}) {
  return showModalBottomSheet<QuoteDetailAction>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _QuoteDetailsSheet(
      shop: shop,
      bom: bom,
      canAccept: canAccept,
      isSelected: isSelected,
    ),
  );
}

class _QuoteDetailsSheet extends StatelessWidget {
  final _ShopOffer shop;
  final List<QuotedLine> bom;
  final bool canAccept;
  final bool isSelected;

  const _QuoteDetailsSheet({
    required this.shop,
    required this.bom,
    required this.canAccept,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    final quote = shop.quote;
    final covered =
        bom.isEmpty ? quote.lines.length : bomCoverageCount(bom, quote);
    final totalItems = bom.isEmpty ? quote.lines.length : bom.length;
    final missing = unquotedBomItems(bom, quote);
    final extras =
        extraQuotedLines(bom, quote).where((line) => line.hasPrice).toList();
    final message = quote.message.trim();
    final profile = shop.profile;
    final listed = bom.isEmpty ? quote.lines : bom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
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
              color: AppColors.cream.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 0, 14, 12),
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
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                      if (profile != null) ...[
                        const SizedBox(height: 4),
                        ShopRatingStars(
                          rating: profile.rating,
                          size: 13,
                          color: const Color(0xFFFBBF77),
                          emptyColor: AppColors.cream.withValues(alpha: 0.28),
                          textColor: AppColors.cream.withValues(alpha: 0.8),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _StatusBadge(status: shop.status),
              ],
            ),
          ),
          Divider(color: AppColors.cream.withValues(alpha: 0.2), height: 1),
          Flexible(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(22, 16, 22, 8),
              children: [
                _SheetSection(
                  title: 'The quote',
                  child: Column(
                    children: [
                      _SheetRow(
                        label: 'Quoted total',
                        value: formatBidMoney(quote.estimatedTotal),
                        strong: true,
                      ),
                      if (quote.leadTimeRaw.trim().isNotEmpty)
                        _SheetRow(
                          label: 'Lead time',
                          value: quote.leadTimeRaw.trim(),
                        ),
                      _SheetRow(
                        label: 'Items quoted',
                        value: totalItems == 0
                            ? 'Lump sum'
                            : '$covered of $totalItems',
                      ),
                    ],
                  ),
                ),
                if (message.isNotEmpty)
                  _SheetSection(
                    title: 'Message from the shop',
                    child: Text(
                      message,
                      style: GoogleFonts.poppins(
                        color: AppColors.cream.withValues(alpha: 0.9),
                        fontSize: 13,
                        height: 1.45,
                      ),
                    ),
                  ),
                if (listed.isNotEmpty)
                  _SheetSection(
                    title: bom.isEmpty ? 'Items quoted' : 'Your materials',
                    child: Column(
                      children: [
                        for (final item in listed)
                          _SheetLineRow(
                            item: item,
                            line: findQuotedLine(quote.lines, item.name),
                          ),
                      ],
                    ),
                  ),
                if (extras.isNotEmpty)
                  _SheetSection(
                    title: 'Extra items this shop added',
                    subtitle: 'Not on your estimate list.',
                    child: Column(
                      children: [
                        for (final line in extras)
                          _SheetLineRow(item: line, line: line),
                      ],
                    ),
                  ),
                if (missing.isNotEmpty)
                  _SheetSection(
                    title: 'Not quoted',
                    subtitle:
                        'This shop skipped these. Another shop may have bid them.',
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final item in missing)
                          _Pill(
                            label: item.name,
                            bg: AppColors.cream.withValues(alpha: 0.10),
                            fg: AppColors.cream.withValues(alpha: 0.85),
                          ),
                      ],
                    ),
                  ),
                if (profile != null) _shopSection(context, profile),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 12, 22, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.cream,
                        side: BorderSide(
                          color: AppColors.cream.withValues(alpha: 0.45),
                        ),
                        minimumSize: const Size(0, 46),
                        shape: const StadiumBorder(),
                      ),
                      child: Text(
                        'Close',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                  if (canAccept || isSelected) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(
                          context,
                          canAccept
                              ? QuoteDetailAction.accept
                              : QuoteDetailAction.message,
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.cream,
                          foregroundColor: AppColors.navy,
                          elevation: 0,
                          minimumSize: const Size(0, 46),
                          shape: const StadiumBorder(),
                        ),
                        child: Text(
                          canAccept ? 'Select shop' : 'Message shop',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _shopSection(BuildContext context, RankedShop profile) {
    final categories = profile.suppliedCategories
        .map(supplyCategoryLabel)
        .where((label) => label.trim().isNotEmpty)
        .toList();
    final location = profile.locationLabel;

    return _SheetSection(
      title: 'About the shop',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (profile.description.trim().isNotEmpty) ...[
            Text(
              profile.description.trim(),
              style: GoogleFonts.poppins(
                color: AppColors.cream.withValues(alpha: 0.9),
                fontSize: 13,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 10),
          ],
          if (location.isNotEmpty)
            _SheetRow(label: 'Address', value: location),
          if (profile.businessHours.trim().isNotEmpty)
            _SheetRow(label: 'Open', value: profile.businessHours.trim()),
          if (profile.phone.trim().isNotEmpty)
            _SheetRow(label: 'Phone', value: profile.phone.trim()),
          if (profile.coverageCities.isNotEmpty) ...[
            const SizedBox(height: 8),
            const _MiniLabel('Coverage areas', light: true),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final area in profile.coverageCities)
                  _Pill(
                    label: area,
                    bg: AppColors.cream.withValues(alpha: 0.10),
                    fg: AppColors.cream.withValues(alpha: 0.85),
                  ),
              ],
            ),
          ],
          if (categories.isNotEmpty) ...[
            const SizedBox(height: 10),
            const _MiniLabel('Supplies', light: true),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final label in categories)
                  _Pill(
                    label: label,
                    bg: AppColors.cream.withValues(alpha: 0.10),
                    fg: AppColors.cream.withValues(alpha: 0.85),
                  ),
              ],
            ),
          ],
          if (profile.hasStorefront) ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => showShopStorefrontSheet(context, profile),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF8FB2D4),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(Icons.storefront_outlined, size: 16),
                label: Text(
                  'Full shop profile',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SheetSection extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;

  const _SheetSection({
    required this.title,
    required this.child,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: GoogleFonts.poppins(
              color: AppColors.cream.withValues(alpha: 0.55),
              fontWeight: FontWeight.w700,
              fontSize: 11,
              letterSpacing: 1.1,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: GoogleFonts.poppins(
                color: AppColors.cream.withValues(alpha: 0.6),
                fontSize: 11.5,
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _SheetRow extends StatelessWidget {
  final String label;
  final String value;
  final bool strong;

  const _SheetRow({
    required this.label,
    required this.value,
    this.strong = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              color: AppColors.cream.withValues(alpha: 0.7),
              fontSize: 12.5,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: strong ? 15 : 12.5,
                fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One material in the sheet: what was asked for, and what this shop put
/// against it.
class _SheetLineRow extends StatelessWidget {
  final QuotedLine item;
  final QuotedLine? line;

  const _SheetLineRow({required this.item, required this.line});

  @override
  Widget build(BuildContext context) {
    final quoted = line?.hasPrice == true;
    final detail = [
      if (item.quantityLabel.isNotEmpty) item.quantityLabel,
      if (item.size.trim().isNotEmpty) item.size.trim(),
    ].join(' · ');

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
                  item.name,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                  ),
                ),
                if (detail.isNotEmpty)
                  Text(
                    detail,
                    style: GoogleFonts.poppins(
                      color: AppColors.cream.withValues(alpha: 0.6),
                      fontSize: 11,
                    ),
                  ),
                if (line?.isSubstitute == true)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      'Substitute: ${line!.name}',
                      style: GoogleFonts.poppins(
                        color: const Color(0xFFFBBF77),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                quoted ? formatBidMoney(line!.lineTotal) : 'No quote',
                style: GoogleFonts.poppins(
                  color: quoted
                      ? Colors.white
                      : AppColors.cream.withValues(alpha: 0.5),
                  fontSize: 13,
                  fontWeight: quoted ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
              if (quoted && line!.unitPrice > 0)
                Text(
                  unitPriceLabel(line!, bom: item),
                  style: GoogleFonts.poppins(
                    color: AppColors.cream.withValues(alpha: 0.6),
                    fontSize: 11,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MaterialCompareCard extends StatelessWidget {
  final QuotedLine item;
  final List<_ShopOffer> shops;

  const _MaterialCompareCard({required this.item, required this.shops});

  @override
  Widget build(BuildContext context) {
    final quotes = shops.map((s) => s.quote).toList();
    final lowest = lowestPricedShopFor(quotes, item.name);
    final quotedCount = shops
        .where((s) => findQuotedLine(s.quote.lines, item.name)?.hasPrice == true)
        .length;

    final detail = [
      if (item.quantityLabel.isNotEmpty) item.quantityLabel,
      if (item.size.trim().isNotEmpty) item.size.trim(),
      '$quotedCount of ${shops.length} quoted',
    ].join('  ·  ');

    return _CreamCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.name,
            style: GoogleFonts.poppins(
              color: AppColors.textDark,
              fontWeight: FontWeight.w800,
              fontSize: 15,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            detail,
            style: GoogleFonts.poppins(
              color: AppColors.textMuted,
              fontSize: 11.5,
            ),
          ),
          const SizedBox(height: 10),
          for (final shop in shops)
            _ComparePriceRow(
              shopName: shop.quote.shopName,
              line: findQuotedLine(shop.quote.lines, item.name),
              item: item,
              isLowest: lowest?.id == shop.quote.id,
            ),
        ],
      ),
    );
  }
}

class _ComparePriceRow extends StatelessWidget {
  final String shopName;
  final QuotedLine? line;
  final QuotedLine item;
  final bool isLowest;

  const _ComparePriceRow({
    required this.shopName,
    required this.line,
    required this.item,
    required this.isLowest,
  });

  @override
  Widget build(BuildContext context) {
    final hasPrice = line?.hasPrice == true;
    final listedWithoutPrice = line != null && !hasPrice;

    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          Expanded(
            child: Text(
              shopName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                color: AppColors.textDark,
                fontWeight: FontWeight.w600,
                fontSize: 12.5,
              ),
            ),
          ),
          if (line?.isSubstitute == true) ...[
            const _Pill(
              label: 'Substitute',
              bg: Color(0xFFFEF3C7),
              fg: Color(0xFF92400E),
              dense: true,
            ),
            const SizedBox(width: 6),
          ],
          if (hasPrice && isLowest) ...[
            const _Pill(
              label: 'Lowest',
              bg: Color(0xFFD1FAE5),
              fg: Color(0xFF065F46),
              dense: true,
            ),
            const SizedBox(width: 8),
          ],
          Text(
            hasPrice
                ? unitPriceLabel(line!, bom: item)
                : listedWithoutPrice
                    ? 'No price'
                    : 'No quote',
            style: GoogleFonts.poppins(
              color: hasPrice
                  ? (isLowest ? AppColors.success : AppColors.textDark)
                  : AppColors.textMuted,
              fontWeight: hasPrice ? FontWeight.w800 : FontWeight.w600,
              fontSize: 12.5,
            ),
          ),
        ],
      ),
    );
  }
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

/// Small caps label above a figure, on a cream card or a navy sheet.
class _MiniLabel extends StatelessWidget {
  final String text;
  final bool light;

  const _MiniLabel(this.text, {this.light = false});

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: GoogleFonts.poppins(
        color: light
            ? AppColors.cream.withValues(alpha: 0.55)
            : AppColors.textMuted,
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
      ),
    );
  }
}

/// One small fact with an icon: lead time, items skipped, extras.
class _Fact extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? tint;

  const _Fact({required this.icon, required this.text, this.tint});

  @override
  Widget build(BuildContext context) {
    final color = tint ?? AppColors.textMuted;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 5),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 190),
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              color: color,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color bg;
  final Color fg;
  final bool dense;

  const _Pill({
    required this.label,
    required this.bg,
    required this.fg,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 7 : 10,
        vertical: dense ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          color: fg,
          fontSize: dense ? 10 : 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _CreamCard extends StatelessWidget {
  final Widget child;
  final Color? borderColor;

  const _CreamCard({required this.child, this.borderColor});

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
              const Icon(
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

/// Where the builder's own decision left this quotation.
///
/// The words are about the decision, not about the document: a builder reads
/// "Selected" and "Not selected", not "accepted" and "rejected".
class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final key = status.toLowerCase();
    final (:label, :bg, :fg) = switch (key) {
      'accepted' => (
          label: 'Selected',
          bg: const Color(0xFFD1FAE5),
          fg: const Color(0xFF065F46),
        ),
      'partially_accepted' => (
          label: 'Partly selected',
          bg: const Color(0xFFD1FAE5),
          fg: const Color(0xFF065F46),
        ),
      'cancelled' => (
          label: 'Cancelled',
          bg: const Color(0xFFFECACA),
          fg: const Color(0xFF991B1B),
        ),
      'rejected' => (
          label: 'Not selected',
          bg: const Color(0xFFE5E7EB),
          fg: const Color(0xFF4B5563),
        ),
      _ => (
          label: 'Open offer',
          bg: const Color(0xFFFEF3C7),
          fg: const Color(0xFF92400E),
        ),
    };

    return _Pill(label: label, bg: bg, fg: fg);
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

    return _Pill(label: label, bg: bg, fg: fg);
  }
}
