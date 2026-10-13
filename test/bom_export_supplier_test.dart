// Sharing an estimate once its supplier is picked: the sheet shows the
// selected shop's substitutes, unavailable lines, agreed prices and amounts,
// and totals only what was ordered.
import 'package:flutter_test/flutter_test.dart';

import 'package:iconstruct/features/bidding/data/item_negotiation.dart';
import 'package:iconstruct/features/project_creation/data/bom_export.dart';
import 'package:iconstruct/features/project_creation/data/bom_export_service.dart';

const _estimate = [
  {
    'name': 'Portland Cement - Floor Screed (40 kg)',
    'quantity': 10,
    'unit': 'bags',
    'category': 'Cement',
  },
  {
    'name': 'Portland Cement - Slab (40 kg)',
    'quantity': 20,
    'unit': 'bags',
    'category': 'Cement',
  },
  {
    'name': 'Sanitary Silicone Sealant (300ml)',
    'quantity': 2,
    'unit': 'tubes',
    'category': 'Plumbing',
  },
  {
    'name': 'Washed Sand - Floor Screed',
    'quantity': 1,
    'unit': 'cu.m',
    'category': 'Aggregates',
  },
];

BomExportData _sheet(
  List<Map<String, dynamic>> quote, {
  String status = 'accepted',
}) => BomExportData.fromQuotation(
  estimateName: 'Master Bathroom',
  renovationType: 'Bathroom Renovation',
  areaSqm: 6,
  materials: _estimate,
  quotationItems: quote,
  quotationStatus: status,
  supplierName: 'Lipa Hardware',
);

BomExportItem _line(BomExportData data, String name) =>
    data.materials.firstWhere((m) => m.name == name);

void main() {
  test('a substitute shows the shop product, instead of the one asked for', () {
    final data = _sheet([
      {
        'name': 'Dow Corning Silicone (280ml)',
        'requestedName': 'Sanitary Silicone Sealant (300ml)',
        'quantity': 2,
        'unit': 'tubes',
        'unitPrice': 185,
        'subtotal': 370,
      },
    ]);

    final line = _line(data, 'Dow Corning Silicone (280ml)');
    expect(line.isSubstitute, isTrue);
    expect(line.requestedName, 'Sanitary Silicone Sealant (300ml)');
    expect(line.unitPrice, 185);
    expect(line.amount, 370);
    expect(data.isSupplierPicked, isTrue);
    expect(data.supplierName, 'Lipa Hardware');
  });

  test('an unavailable line has no amount and is not totalled', () {
    final data = _sheet([
      {
        'name': 'Washed Sand - Floor Screed',
        'quantity': 1,
        'unit': 'cu.m',
        'unitPrice': 1500,
        'available': false,
      },
      {
        'name': 'Portland Cement - Slab (40 kg)',
        'quantity': 20,
        'unit': 'bags',
        'unitPrice': 260,
        'subtotal': 5200,
      },
    ]);

    final sand = _line(data, 'Washed Sand - Floor Screed');
    expect(sand.isUnavailable, isTrue);
    expect(sand.amount, 0);
    expect(data.totalAmount, 5200);
  });

  test('an accepted counter-offer shows the agreed unit price and amount', () {
    final quoted = {
      'name': 'Portland Cement - Slab (40 kg)',
      'quantity': 20,
      'unit': 'bags',
      'unitPrice': 280,
      'subtotal': 5600,
    };
    // Accepting a counter-offer rewrites the line's prices this way.
    final agreed = repricedLine(quoted, 250);

    final line = _line(_sheet([agreed]), 'Portland Cement - Slab (40 kg)');
    expect(line.unitPrice, 250);
    expect(line.amount, 5000);
  });

  test('exact names are matched before partial ones', () {
    final data = _sheet([
      {
        'name': 'Portland Cement - Slab (40 kg)',
        'quantity': 20,
        'unit': 'bags',
        'unitPrice': 260,
        'subtotal': 5200,
      },
      {
        'name': 'Portland Cement - Floor Screed (40 kg)',
        'quantity': 10,
        'unit': 'bags',
        'unitPrice': 250,
        'subtotal': 2500,
      },
    ]);

    expect(_line(data, 'Portland Cement - Floor Screed (40 kg)').amount, 2500);
    expect(_line(data, 'Portland Cement - Slab (40 kg)').amount, 5200);
  });

  test('lines left out of a partly accepted quotation are not ordered', () {
    final quote = [
      {
        'name': 'Portland Cement - Slab (40 kg)',
        'quantity': 20,
        'unit': 'bags',
        'unitPrice': 260,
        'subtotal': 5200,
        'accepted': true,
      },
      {
        'name': 'Portland Cement - Floor Screed (40 kg)',
        'quantity': 10,
        'unit': 'bags',
        'unitPrice': 300,
        'subtotal': 3000,
        'accepted': false,
        'declineReason': 'overpriced',
      },
    ];

    final partial = _sheet(quote, status: 'partially_accepted');
    final screed = _line(partial, 'Portland Cement - Floor Screed (40 kg)');
    expect(screed.isDeclined, isTrue);
    expect(screed.declineReason, 'Overpriced');
    expect(screed.unitPrice, 300);
    expect(partial.totalAmount, 5200);

    // The flags mean nothing on a quotation that was accepted in full.
    final full = _sheet(quote);
    expect(
      _line(full, 'Portland Cement - Floor Screed (40 kg)').isDeclined,
      isFalse,
    );
    expect(full.totalAmount, 8200);
  });

  test('a line the shop did not quote keeps the estimate and no price', () {
    final data = _sheet(const []);
    final line = _line(data, 'Washed Sand - Floor Screed');
    expect(line.hasPrice, isFalse);
    expect(line.quantity, 1);
    expect(data.totalAmount, 0);
  });

  test(
    'the sheet with every kind of line renders as a PDF and an image',
    () async {
      final data = _sheet([
        {
          'name': 'Dow Corning Silicone (280ml)',
          'requestedName': 'Sanitary Silicone Sealant (300ml)',
          'quantity': 2,
          'unitPrice': 185,
          'accepted': true,
        },
        {
          'name': 'Washed Sand - Floor Screed',
          'quantity': 1,
          'available': false,
          'accepted': true,
        },
        {
          'name': 'Portland Cement - Floor Screed (40 kg)',
          'quantity': 10,
          'unitPrice': 300,
          'accepted': false,
          'declineReason': 'not_needed',
        },
      ], status: 'partially_accepted');

      final pdf = await BomExportService.buildPdf(data);
      final image = await BomExportService.buildPdf(data, forImage: true);
      expect(pdf.length, greaterThan(1000));
      expect(image.length, greaterThan(1000));
      expect(
        _line(data, 'Portland Cement - Floor Screed (40 kg)').declineReason,
        'Not needed',
      );
    },
  );
}
