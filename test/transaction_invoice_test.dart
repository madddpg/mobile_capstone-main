import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:iconstruct/features/chat/data/transaction_invoice.dart';
import 'package:iconstruct/features/chat/data/transaction_invoice_pdf_service.dart';
import 'package:iconstruct/features/project_creation/data/bom_export_service.dart';
import 'package:iconstruct/features/project_creation/data/bom_export.dart';

void main() {
  group('TransactionInvoice Detection & Parsing', () {
    test('isInvoiceMessage identifies quotation_invoice type', () {
      expect(
        TransactionInvoice.isInvoiceMessage({'type': 'quotation_invoice'}),
        isTrue,
      );
      expect(
        TransactionInvoice.isInvoiceMessage({'type': 'QUOTATION_INVOICE'}),
        isTrue,
      );
      expect(
        TransactionInvoice.isInvoiceMessage({'type': 'invoice'}),
        isTrue,
      );
    });

    test('isInvoiceMessage identifies [OFFICIAL_TRANSACTION_INVOICE] text prefix', () {
      expect(
        TransactionInvoice.isInvoiceMessage({
          'text': '[OFFICIAL_TRANSACTION_INVOICE] Quotation Ref #Q-1234 confirmed',
        }),
        isTrue,
      );
      expect(
        TransactionInvoice.isInvoiceMessage({
          'text': 'Hello, when can you deliver the cement?',
        }),
        isFalse,
      );
      expect(
        TransactionInvoice.isInvoiceMessage({
          'type': 'text',
          'text': 'Normal message',
        }),
        isFalse,
      );
    });

    test('fromMessage correctly parses invoice and snapshot fields', () {
      final message = <String, dynamic>{
        'type': 'quotation_invoice',
        'quotationId': 'quote-abc-12345',
        'projectId': 'post-project-789',
        'acceptedTotal': 45250.50,
        'text': '[OFFICIAL_TRANSACTION_INVOICE] Order confirmed',
        'quotationSnapshot': {
          'projectTitle': 'Kitchen & Dining Renovation',
          'shopName': 'Lipa Central Hardware',
          'builderName': 'Juan dela Cruz',
          'items': [
            {
              'name': 'Portland Cement Type 1 (40kg)',
              'quantity': 50,
              'unit': 'bags',
              'unitPrice': 245.0,
              'subtotal': 12250.0,
              'accepted': true,
            },
            {
              'name': '10mm Deformed Steel Bar Grade 40',
              'quantity': 100,
              'unit': 'pcs',
              'unitPrice': 330.0,
              'subtotal': 33000.0,
              'accepted': true,
            },
            {
              'name': 'Tie Wire #16',
              'quantity': 5,
              'unit': 'kg',
              'unitPrice': 95.0,
              'subtotal': 475.0,
              'accepted': false, // Dropped / not accepted
            },
          ],
        },
      };

      final invoice = TransactionInvoice.fromMessage(message);

      expect(invoice.quotationId, 'quote-abc-12345');
      expect(invoice.projectId, 'post-project-789');
      expect(invoice.acceptedTotal, 45250.50);
      expect(invoice.projectTitle, 'Kitchen & Dining Renovation');
      expect(invoice.shopName, 'Lipa Central Hardware');
      expect(invoice.builderName, 'Juan dela Cruz');
      expect(invoice.formattedTotal, '₱45,250.50');
      expect(invoice.referenceNumber, 'ABC12345');

      // Only accepted items are included
      expect(invoice.items.length, 2);
      expect(invoice.items[0].name, 'Portland Cement Type 1 (40kg)');
      expect(invoice.items[0].quantity, 50.0);
      expect(invoice.items[0].unit, 'bags');
      expect(invoice.items[0].unitPrice, 245.0);
      expect(invoice.items[0].total, 12250.0);

      expect(invoice.items[1].name, '10mm Deformed Steel Bar Grade 40');
      expect(invoice.items[1].total, 33000.0);
    });

    test('fromMessage falls back cleanly when snapshot is minimal', () {
      final message = <String, dynamic>{
        'type': 'quotation_invoice',
        'quotationId': 'q-999',
        'projectId': 'p-888',
        'acceptedTotal': 1500,
      };

      final invoice = TransactionInvoice.fromMessage(
        message,
        conversation: {
          'projectTitle': 'Bathroom Tile Installation',
          'shopName': 'Cavite Builders Depot',
        },
      );

      expect(invoice.quotationId, 'q-999');
      expect(invoice.projectId, 'p-888');
      expect(invoice.acceptedTotal, 1500.0);
      expect(invoice.projectTitle, 'Bathroom Tile Installation');
      expect(invoice.shopName, 'Cavite Builders Depot');
      expect(invoice.formattedTotal, '₱1,500.00');
      expect(invoice.referenceNumber, 'Q999');
    });
  });

  group('TransactionInvoicePdfService Generation & Disclaimers', () {
    test('pdfSafe cleans peso signs and typographic symbols', () {
      expect(
        TransactionInvoicePdfService.pdfSafe('Total: ₱15,000.00 — “Tiles”'),
        'Total: PHP 15,000.00  -  "Tiles"',
      );
    });

    test('buildPdf generates non-empty PDF bytes', () async {
      final invoice = TransactionInvoice(
        quotationId: 'quotation-xyz-777',
        projectId: 'project-123',
        acceptedTotal: 18500.0,
        projectTitle: 'Master Bedroom Extension',
        shopName: 'Antipolo Hardware Hub',
        builderName: 'Maria Santos',
        issuedAt: DateTime(2026, 10, 17, 9, 30),
        items: const [
          TransactionInvoiceItem(
            name: 'Marine Plywood 1/2"',
            quantity: 10,
            unit: 'sheets',
            unitPrice: 850.0,
            total: 8500.0,
          ),
          TransactionInvoiceItem(
            name: '2x3x12 Good Lumber',
            quantity: 40,
            unit: 'pcs',
            unitPrice: 250.0,
            total: 10000.0,
          ),
        ],
      );

      final pdfBytes = await TransactionInvoicePdfService.buildPdf(invoice);
      expect(pdfBytes, isA<Uint8List>());
      expect(pdfBytes.length, greaterThan(1000));
    });

    test('systemGeneratedDisclaimer is present in TransactionInvoicePdfService', () {
      expect(
        TransactionInvoicePdfService.systemGeneratedDisclaimer,
        contains('This is a system-generated Quotation & Transaction Invoice issued by iConstruct'),
      );
      expect(
        TransactionInvoicePdfService.systemGeneratedDisclaimer,
        contains('No physical signature is required'),
      );
    });

    test('BomExportService buildPdf succeeds with system-generated footer disclaimer', () async {
      final sampleBom = BomExportData(
        estimateName: 'Roofing Replacement',
        renovationType: 'Structural',
        areaSqm: 40.0,
        materials: const [
          BomExportItem(
            name: 'Corrugated GI Sheet 8ft',
            category: 'Roofing',
            quantity: 20,
            unit: 'pcs',
            unitPrice: 420.0,
            amount: 8400.0,
          ),
        ],
      );

      final pdfBytes = await BomExportService.buildPdf(sampleBom);
      expect(pdfBytes, isA<Uint8List>());
      expect(pdfBytes.length, greaterThan(1000));
    });
  });
}
