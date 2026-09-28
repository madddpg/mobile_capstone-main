import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:iconstruct/core/firebase/firestore_error.dart';
import 'package:iconstruct/core/theme/app_theme.dart';
import 'package:iconstruct/core/widgets/app_message.dart';
import 'package:iconstruct/features/bidding/data/bid_comparison.dart';
import 'package:iconstruct/features/bidding/data/item_negotiation.dart';
import 'package:iconstruct/features/bidding/data/partial_acceptance.dart';
import 'package:iconstruct/features/bidding/data/quotation_accept_service.dart';

/// The shop's lower prices on lines the builder left as overpriced.
///
/// An offer waiting on the builder gets Take it and Turn down. Answered ones
/// stay listed, quietly, so the builder can see what was agreed and whether
/// the shop may still come back with another price.
class CounterOffersPanel extends StatefulWidget {
  final Map<String, dynamic> quotationData;
  final String postId;
  final String quotationId;
  final String shopName;

  const CounterOffersPanel({
    super.key,
    required this.quotationData,
    required this.postId,
    required this.quotationId,
    required this.shopName,
  });

  /// Whether the quotation has any counter-offer to show.
  static bool hasOffers(Map<String, dynamic> quotationData) => quotationItems(
    quotationData,
  ).any((item) => ItemNegotiation.fromItem(item) != null);

  @override
  State<CounterOffersPanel> createState() => _CounterOffersPanelState();
}

class _CounterOffersPanelState extends State<CounterOffersPanel> {
  /// The line being answered, so its buttons wait for the write.
  int? _busyIndex;

  Future<void> _answer(int index, bool accept) async {
    final items = quotationItems(widget.quotationData);
    final item = items[index];
    final negotiation = ItemNegotiation.fromItem(item)!;

    if (accept) {
      final name = _nameOf(item);
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Take $name?'),
          content: Text(
            '${_offerPrice(item, negotiation)}. It adds '
            '${formatBidMoney(lineTotalAtOffer(item, negotiation.shopOfferedPrice))} '
            'to your order with ${widget.shopName}.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Take it'),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }

    setState(() => _busyIndex = index);
    try {
      await QuotationAcceptService().respondToCounterOffer(
        postId: widget.postId,
        quotationId: widget.quotationId,
        itemIndex: index,
        accept: accept,
      );
    } catch (error) {
      if (!mounted) return;
      final message = error is FirebaseException
          ? firestoreUserMessage(error, action: 'answer this offer')
          : error.toString().replaceFirst(RegExp(r'^Exception: '), '');
      showAppMessage(
        context,
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _busyIndex = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = quotationItems(widget.quotationData);
    final offers = [
      for (var i = 0; i < items.length; i++)
        if (ItemNegotiation.fromItem(items[i]) case final negotiation?)
          (index: i, item: items[i], negotiation: negotiation),
    ];
    if (offers.isEmpty) return const SizedBox.shrink();

    final waiting = offers.where((o) => o.negotiation.isPending).length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: waiting > 0
            ? const Color(0xFFFFFBF0)
            : AppColors.navy.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: waiting > 0 ? Border.all(color: const Color(0xFFF3C969)) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            waiting == 0
                ? 'Price offers'
                : waiting == 1
                ? '${widget.shopName} offered a lower price'
                : '${widget.shopName} offered $waiting lower prices',
            style: GoogleFonts.poppins(
              color: AppColors.textDark,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          for (final offer in offers) ...[
            const SizedBox(height: 10),
            _OfferRow(
              item: offer.item,
              negotiation: offer.negotiation,
              shopName: widget.shopName,
              busy: _busyIndex == offer.index,
              enabled: _busyIndex == null,
              onAnswer: (accept) => _answer(offer.index, accept),
            ),
          ],
        ],
      ),
    );
  }
}

String _nameOf(Map<String, dynamic> item) {
  final name = quotedItemName(item);
  return name.isEmpty ? 'this item' : name;
}

/// "₱320 each instead of ₱343", or the line's new total for a lump line.
String _offerPrice(Map<String, dynamic> item, ItemNegotiation negotiation) {
  final offered = formatBidMoney(negotiation.shopOfferedPrice);
  final before = priceBeforeCounterOffer(item);
  final each = counterOfferIsPerUnit(item) ? ' each' : '';
  return before > 0
      ? '$offered$each instead of ${formatBidMoney(before)}'
      : '$offered$each';
}

class _OfferRow extends StatelessWidget {
  final Map<String, dynamic> item;
  final ItemNegotiation negotiation;
  final String shopName;
  final bool busy;
  final bool enabled;
  final ValueChanged<bool> onAnswer;

  const _OfferRow({
    required this.item,
    required this.negotiation,
    required this.shopName,
    required this.busy,
    required this.enabled,
    required this.onAnswer,
  });

  @override
  Widget build(BuildContext context) {
    final offered = formatBidMoney(negotiation.shopOfferedPrice);
    final each = counterOfferIsPerUnit(item) ? ' each' : '';

    final (detail, tint) = switch (negotiation.status) {
      ItemNegotiation.statusAccepted => (
        'Taken at $offered$each.',
        AppColors.success,
      ),
      ItemNegotiation.statusDeclined => (
        negotiation.mayCounterAgain
            ? 'You turned down $offered$each. $shopName may send one more '
                  'offer.'
            : 'You turned down $offered$each. No more offers on this line.',
        AppColors.textMuted,
      ),
      _ => (_pendingDetail(), AppColors.textDark),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _nameOf(item),
          style: GoogleFonts.poppins(
            color: AppColors.textDark,
            fontWeight: FontWeight.w600,
            fontSize: 12.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          detail,
          style: GoogleFonts.poppins(color: tint, fontSize: 12, height: 1.35),
        ),
        if (negotiation.isPending) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: enabled ? () => onAnswer(false) : null,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.navySoft,
                    side: BorderSide(
                      color: AppColors.navySoft.withValues(alpha: 0.45),
                    ),
                    minimumSize: const Size(0, 40),
                    shape: const StadiumBorder(),
                  ),
                  child: Text(
                    'Turn down',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: enabled ? () => onAnswer(true) : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.navySoft,
                    foregroundColor: AppColors.cream,
                    elevation: 0,
                    minimumSize: const Size(0, 40),
                    shape: const StadiumBorder(),
                  ),
                  child: busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.cream,
                          ),
                        )
                      : Text(
                          'Take it',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  String _pendingDetail() {
    final total = lineTotalAtOffer(item, negotiation.shopOfferedPrice);
    final quantity = counterOfferIsPerUnit(item)
        ? ' That comes to ${formatBidMoney(total)} for the line.'
        : '';
    return '$shopName offers ${_offerPrice(item, negotiation)}.$quantity';
  }
}
