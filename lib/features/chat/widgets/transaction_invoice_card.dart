import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:iconstruct/core/theme/app_theme.dart';
import 'package:iconstruct/core/widgets/app_buttons.dart';
import 'package:iconstruct/core/widgets/iconstruct_panel.dart';
import 'package:iconstruct/features/chat/data/transaction_invoice.dart';
import 'package:iconstruct/features/chat/data/transaction_invoice_pdf_service.dart';

/// Renders a verified Quotation & Transaction Invoice message card inside the chat thread.
///
/// Dispatched when a hardware shop accepts a homeowner's quotation order. Includes
/// reference numbers, Confirmed & Secured status badge, total items accepted,
/// confirmed amount in PHP, and a one-click "Download PDF Quotation / Invoice" button.
class TransactionInvoiceCard extends StatefulWidget {
  final TransactionInvoice invoice;
  final VoidCallback? onInvoiceUpdated;

  const TransactionInvoiceCard({
    super.key,
    required this.invoice,
    this.onInvoiceUpdated,
  });

  @override
  State<TransactionInvoiceCard> createState() => _TransactionInvoiceCardState();
}

class _TransactionInvoiceCardState extends State<TransactionInvoiceCard> {
  bool _busy = false;
  bool _showItems = false;
  late TransactionInvoice _invoice;

  @override
  void initState() {
    super.initState();
    _invoice = widget.invoice;
  }

  @override
  void didUpdateWidget(covariant TransactionInvoiceCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.invoice != oldWidget.invoice) {
      _invoice = widget.invoice;
    }
  }

  Future<TransactionInvoice> _resolveInvoice() async {
    if (_invoice.items.isNotEmpty) return _invoice;
    setState(() => _busy = true);
    try {
      final resolved = await _invoice.resolveFromFirestoreIfEmpty(
        firestore: FirebaseFirestore.instance,
      );
      if (mounted) {
        setState(() {
          _invoice = resolved;
          _busy = false;
        });
      }
      return resolved;
    } catch (_) {
      if (mounted) setState(() => _busy = false);
      return _invoice;
    }
  }

  Future<void> _handleDownloadPdf() async {
    setState(() => _busy = true);
    try {
      final invoice = await _resolveInvoice();
      await TransactionInvoicePdfService.printOrSavePdf(invoice);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text('Failed to generate PDF: $e'),
          backgroundColor: Colors.red.shade800,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _handleSharePdf() async {
    setState(() => _busy = true);
    try {
      final invoice = await _resolveInvoice();
      await TransactionInvoicePdfService.sharePdf(invoice);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text('Failed to share PDF: $e'),
          backgroundColor: Colors.red.shade800,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final emerald = const Color(0xFF10B981);
    final emeraldBg = const Color(0xFF064E3B);
    final emeraldLight = const Color(0xFF34D399);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1B2838),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: emerald.withValues(alpha: 0.45),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top Bar with Reference and Confirmed & Secured Badge
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 14, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: emeraldBg,
                    shape: BoxShape.circle,
                    border: Border.all(color: emerald.withValues(alpha: 0.6)),
                  ),
                  child: Icon(
                    Icons.receipt_long_rounded,
                    color: emeraldLight,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'OFFICIAL INVOICE',
                        style: GoogleFonts.poppins(
                          color: AppColors.cream.withValues(alpha: 0.65),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                      Text(
                        'Ref #${_invoice.referenceNumber}',
                        style: GoogleFonts.poppins(
                          color: AppColors.cream,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                // Confirmed & Secured Status Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: emeraldBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: emerald, width: 1.1),
                    boxShadow: [
                      BoxShadow(
                        color: emerald.withValues(alpha: 0.25),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.verified_rounded,
                        color: emeraldLight,
                        size: 13,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Confirmed & Secured',
                        style: GoogleFonts.poppins(
                          color: emeraldLight,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Divider
          Container(
            height: 1,
            color: AppColors.cream.withValues(alpha: 0.12),
          ),

          // Project Title & Parties Info
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _invoice.projectTitle,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.storefront_outlined,
                      size: 13,
                      color: AppColors.cream.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        _invoice.shopName,
                        style: GoogleFonts.poppins(
                          color: AppColors.cream.withValues(alpha: 0.85),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Text(
                      _invoice.formattedIssuedDate,
                      style: GoogleFonts.poppins(
                        color: AppColors.cream.withValues(alpha: 0.5),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Total Items & Confirmed Amount Box
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.cream.withValues(alpha: 0.1),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ACCEPTED ITEMS',
                      style: GoogleFonts.poppins(
                        color: AppColors.cream.withValues(alpha: 0.55),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Text(
                          '${_invoice.itemsCount} ${_invoice.itemsCount == 1 ? 'item' : 'items'}',
                          style: GoogleFonts.poppins(
                            color: AppColors.cream,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (_invoice.items.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          InkWell(
                            onTap: () => setState(() => _showItems = !_showItems),
                            child: Padding(
                              padding: const EdgeInsets.all(2),
                              child: Row(
                                children: [
                                  Text(
                                    _showItems ? 'Hide' : 'View',
                                    style: GoogleFonts.poppins(
                                      color: emeraldLight,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Icon(
                                    _showItems
                                        ? Icons.keyboard_arrow_up_rounded
                                        : Icons.keyboard_arrow_down_rounded,
                                    size: 14,
                                    color: emeraldLight,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'CONFIRMED TOTAL',
                      style: GoogleFonts.poppins(
                        color: AppColors.cream.withValues(alpha: 0.55),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _invoice.formattedTotal,
                      style: GoogleFonts.poppins(
                        color: emeraldLight,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Expandable Items Breakdown
          if (_showItems && _invoice.items.isNotEmpty)
            Container(
              margin: const EdgeInsets.fromLTRB(14, 6, 14, 4),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < _invoice.items.length; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${_invoice.items[i].name} (${_invoice.items[i].quantity % 1 == 0 ? _invoice.items[i].quantity.toInt() : _invoice.items[i].quantity} ${_invoice.items[i].unit})',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                color: AppColors.cream.withValues(alpha: 0.9),
                                fontSize: 11.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '₱${TransactionInvoice.formatNumber(_invoice.items[i].total)}',
                            style: GoogleFonts.poppins(
                              color: AppColors.cream,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

          // Download PDF Quotation / Invoice Button
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _busy ? null : _handleDownloadPdf,
                    icon: _busy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.picture_as_pdf_rounded, size: 18),
                    label: Text(
                      _busy ? 'Preparing Invoice...' : 'Download PDF Quotation / Invoice',
                      style: GoogleFonts.poppins(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFC59A4E), // AppColors.brandGold
                      foregroundColor: const Color(0xFF1E293B),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Share invoice PDF',
                  onPressed: _busy ? null : _handleSharePdf,
                  icon: const Icon(Icons.share_outlined, size: 20),
                  color: AppColors.cream,
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.cream.withValues(alpha: 0.12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.all(11),
                  ),
                ),
              ],
            ),
          ),

          // Security & Disclaimer note
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.lock_outline_rounded,
                  size: 11,
                  color: AppColors.cream.withValues(alpha: 0.45),
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    'System-generated official invoice record. No signature required.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      color: AppColors.cream.withValues(alpha: 0.45),
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
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
