import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import 'package:iconstruct/features/chat/data/transaction_invoice.dart';

/// Generates official PDF documents for confirmed quotation transaction invoices.
class TransactionInvoicePdfService {
  TransactionInvoicePdfService._();

  /// Standard disclaimer included on all system-generated transaction exports.
  static const String systemGeneratedDisclaimer =
      'This is a system-generated Quotation & Transaction Invoice issued by iConstruct. '
      'No physical signature is required. This document serves as official proof of an '
      'accepted transaction between the builder and the hardware shop.';

  /// Sanitizes text for PDF generation by converting unsupported Unicode symbols to Latin-1 safe strings.
  static String pdfSafe(String text) {
    const replacements = {
      '\u2018': "'",
      '\u2019': "'",
      '\u201C': '"',
      '\u201D': '"',
      '\u2014': ' - ',
      '\u2013': ' - ',
      '\u2026': '...',
      '\u00D7': 'x',
      '\u20B1': 'PHP ',
    };
    var sanitized = text;
    replacements.forEach((key, val) {
      sanitized = sanitized.replaceAll(key, val);
    });
    return sanitized;
  }

  /// Builds the complete PDF bytes for an official transaction invoice.
  static Future<Uint8List> buildPdf(TransactionInvoice invoice) async {
    final doc = pw.Document(
      title: pdfSafe('Invoice - ${invoice.projectTitle}'),
      author: 'iConstruct Smart Material Estimator',
    );

    final navy = PdfColor.fromInt(0xFF1E293B);
    final slate = PdfColor.fromInt(0xFF334155);
    final muted = PdfColor.fromInt(0xFF64748B);
    final borderCol = PdfColor.fromInt(0xFFCBD5E1);
    final green = PdfColor.fromInt(0xFF059669);
    final greenLight = PdfColor.fromInt(0xFFD1FAE5);
    final altRow = PdfColor.fromInt(0xFFF8FAFC);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => _buildHeader(invoice, navy, green, greenLight, muted),
        footer: (context) => _buildFooter(context, muted, borderCol),
        build: (context) => [
          pw.SizedBox(height: 14),
          _buildPartyInfo(invoice, navy, slate, muted, borderCol),
          pw.SizedBox(height: 16),
          _buildItemsTable(invoice, navy, slate, muted, borderCol, altRow),
          pw.SizedBox(height: 16),
          _buildTotals(invoice, navy, green, borderCol),
          pw.SizedBox(height: 18),
          _buildLegalNotice(invoice, slate, muted, borderCol),
        ],
      ),
    );

    return doc.save();
  }

  static pw.Widget _buildHeader(
    TransactionInvoice invoice,
    PdfColor navy,
    PdfColor green,
    PdfColor greenLight,
    PdfColor muted,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'iConstruct',
                  style: pw.TextStyle(
                    fontSize: 22,
                    fontWeight: pw.FontWeight.bold,
                    color: navy,
                  ),
                ),
                pw.Text(
                  'Smart Material Estimator & Bidding Process Support System',
                  style: pw.TextStyle(
                    fontSize: 8,
                    color: muted,
                  ),
                ),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: pw.BoxDecoration(
                    color: greenLight,
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                    border: pw.Border.all(color: green, width: 0.8),
                  ),
                  child: pw.Text(
                    'CONFIRMED & SECURED',
                    style: pw.TextStyle(
                      fontSize: 8.5,
                      fontWeight: pw.FontWeight.bold,
                      color: green,
                    ),
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Ref: #${invoice.referenceNumber}',
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    color: navy,
                  ),
                ),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Container(
          width: double.infinity,
          height: 1.5,
          color: navy,
        ),
      ],
    );
  }

  static pw.Widget _buildPartyInfo(
    TransactionInvoice invoice,
    PdfColor navy,
    PdfColor slate,
    PdfColor muted,
    PdfColor borderCol,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        border: pw.Border.all(color: borderCol, width: 0.8),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'HOMEOWNER / BUILDER',
                  style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: muted),
                ),
                pw.SizedBox(height: 3),
                pw.Text(
                  pdfSafe(invoice.builderName),
                  style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: navy),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  pdfSafe('Project: ${invoice.projectTitle}'),
                  style: pw.TextStyle(fontSize: 9, color: slate),
                ),
                pw.Text(
                  pdfSafe('Post ID: ${invoice.projectId}'),
                  style: pw.TextStyle(fontSize: 8, color: muted),
                ),
              ],
            ),
          ),
          pw.SizedBox(width: 16),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'HARDWARE SHOP / SUPPLIER',
                  style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: muted),
                ),
                pw.SizedBox(height: 3),
                pw.Text(
                  pdfSafe(invoice.shopName),
                  style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: navy),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  pdfSafe('Quote ID: ${invoice.quotationId}'),
                  style: pw.TextStyle(fontSize: 9, color: slate),
                ),
                pw.Text(
                  pdfSafe('Confirmed: ${invoice.formattedIssuedDate}'),
                  style: pw.TextStyle(fontSize: 8, color: muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildItemsTable(
    TransactionInvoice invoice,
    PdfColor navy,
    PdfColor slate,
    PdfColor muted,
    PdfColor borderCol,
    PdfColor altRow,
  ) {
    final headers = ['#', 'Item Description', 'Qty', 'Unit', 'Unit Price (PHP)', 'Total (PHP)'];

    final items = invoice.items;
    if (items.isEmpty) {
      return pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 20),
        alignment: pw.Alignment.center,
        child: pw.Text(
          'Confirmed Order: ${invoice.projectTitle} - Total Amount: PHP ${TransactionInvoice.formatNumber(invoice.acceptedTotal)}',
          style: pw.TextStyle(fontSize: 10, color: slate, fontStyle: pw.FontStyle.italic),
        ),
      );
    }

    return pw.Table(
      border: pw.TableBorder.all(color: borderCol, width: 0.5),
      columnWidths: const {
        0: pw.FixedColumnWidth(24),
        1: pw.FlexColumnWidth(4),
        2: pw.FixedColumnWidth(36),
        3: pw.FixedColumnWidth(38),
        4: pw.FixedColumnWidth(70),
        5: pw.FixedColumnWidth(75),
      },
      children: [
        // Header
        pw.TableRow(
          decoration: pw.BoxDecoration(color: navy),
          children: headers.map((h) {
            final isRight = h.contains('(PHP)') || h == 'Qty';
            return pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              child: pw.Text(
                h,
                textAlign: isRight ? pw.TextAlign.right : pw.TextAlign.left,
                style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
              ),
            );
          }).toList(),
        ),
        // Item Rows
        for (var i = 0; i < items.length; i++)
          pw.TableRow(
            decoration: pw.BoxDecoration(
              color: i % 2 == 1 ? altRow : PdfColors.white,
            ),
            children: [
              pw.Padding(
                padding: const pw.EdgeInsets.all(5),
                child: pw.Text('${i + 1}', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 8, color: muted)),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(5),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(pdfSafe(items[i].name), style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: navy)),
                    if (items[i].notes != null && items[i].notes!.isNotEmpty)
                      pw.Text(pdfSafe(items[i].notes!), style: pw.TextStyle(fontSize: 7, color: muted, fontStyle: pw.FontStyle.italic)),
                  ],
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(5),
                child: pw.Text(
                  items[i].quantity % 1 == 0 ? items[i].quantity.toInt().toString() : items[i].quantity.toStringAsFixed(1),
                  textAlign: pw.TextAlign.right,
                  style: pw.TextStyle(fontSize: 8.5, color: slate),
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(5),
                child: pw.Text(pdfSafe(items[i].unit), style: pw.TextStyle(fontSize: 8.5, color: slate)),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(5),
                child: pw.Text(
                  TransactionInvoice.formatNumber(items[i].unitPrice),
                  textAlign: pw.TextAlign.right,
                  style: pw.TextStyle(fontSize: 8.5, color: slate),
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(5),
                child: pw.Text(
                  TransactionInvoice.formatNumber(items[i].total),
                  textAlign: pw.TextAlign.right,
                  style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: navy),
                ),
              ),
            ],
          ),
      ],
    );
  }

  static pw.Widget _buildTotals(
    TransactionInvoice invoice,
    PdfColor navy,
    PdfColor green,
    PdfColor borderCol,
  ) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromInt(0xFFF1F5F9),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'TRANSACTION STATUS: VERIFIED & CONFIRMED',
                  style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: green),
                ),
                pw.SizedBox(height: 3),
                pw.Text(
                  'Quotation accepted by homeowner and confirmed by hardware shop. Coordination proceeds directly via iConstruct chat.',
                  style: pw.TextStyle(fontSize: 7.5, color: PdfColor.fromInt(0xFF475569)),
                ),
              ],
            ),
          ),
        ),
        pw.SizedBox(width: 20),
        pw.Container(
          width: 200,
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: borderCol, width: 1),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
          ),
          child: pw.Column(
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Total Items:', style: pw.TextStyle(fontSize: 8.5, color: PdfColor.fromInt(0xFF64748B))),
                  pw.Text('${invoice.itemsCount} accepted', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: navy)),
                ],
              ),
              pw.Divider(color: borderCol, thickness: 0.5),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('TOTAL (PHP):', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: navy)),
                  pw.Text(
                    'PHP ${TransactionInvoice.formatNumber(invoice.acceptedTotal)}',
                    style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: green),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildLegalNotice(
    TransactionInvoice invoice,
    PdfColor slate,
    PdfColor muted,
    PdfColor borderCol,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: borderCol, width: 0.6),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'IMPORTANT DISCLAIMER & NOTICE',
            style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: slate),
          ),
          pw.SizedBox(height: 3),
          pw.Text(
            systemGeneratedDisclaimer,
            style: pw.TextStyle(fontSize: 7, color: muted, height: 1.3),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildFooter(pw.Context context, PdfColor muted, PdfColor borderCol) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 8),
      padding: const pw.EdgeInsets.only(top: 6),
      decoration: pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: borderCol, width: 0.5)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            systemGeneratedDisclaimer,
            style: pw.TextStyle(fontSize: 6.5, color: muted),
          ),
          pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: pw.TextStyle(fontSize: 6.5, color: muted),
          ),
        ],
      ),
    );
  }

  /// Opens the platform print / save-as-PDF preview.
  static Future<void> printOrSavePdf(TransactionInvoice invoice) async {
    await Printing.layoutPdf(
      name: 'Invoice-${invoice.referenceNumber}.pdf',
      onLayout: (format) => buildPdf(invoice),
    );
  }

  /// Opens the system share sheet with the invoice PDF file.
  static Future<void> sharePdf(TransactionInvoice invoice) async {
    final bytes = await buildPdf(invoice);
    final fileName = 'Invoice-${invoice.referenceNumber}.pdf';

    if (kIsWeb) {
      await Printing.sharePdf(bytes: bytes, filename: fileName);
      return;
    }

    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes, flush: true);

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/pdf', name: fileName)],
        text: 'Official Quotation & Transaction Invoice for "${invoice.projectTitle}" (Ref: #${invoice.referenceNumber})',
      );
    } catch (_) {
      await Printing.sharePdf(bytes: bytes, filename: fileName);
    }
  }
}
