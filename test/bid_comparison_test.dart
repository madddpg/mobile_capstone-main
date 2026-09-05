import 'package:flutter_test/flutter_test.dart';
import 'package:iconstruct/features/bidding/data/bid_comparison.dart';

void main() {
  group('BidQuote.parseLeadTimeDays', () {
    test('parses common lead-time phrases', () {
      expect(BidQuote.parseLeadTimeDays('3 days'), 3);
      expect(BidQuote.parseLeadTimeDays('1 week'), 7);
      expect(BidQuote.parseLeadTimeDays('2 weeks'), 14);
    });
  });

  group('BidComparison', () {
    final quotes = [
      const BidQuote(
        id: 'a',
        shopName: 'Alpha Hardware',
        estimatedTotal: 10000,
        deliveryFee: 500,
        leadTimeRaw: '5 days',
        materialsCovered: 4,
      ),
      const BidQuote(
        id: 'b',
        shopName: 'Beta Supply',
        estimatedTotal: 9500,
        deliveryFee: 0,
        leadTimeRaw: '2 weeks',
        materialsCovered: 8,
      ),
      const BidQuote(
        id: 'c',
        shopName: 'QuickBuild',
        estimatedTotal: 11000,
        deliveryFee: 200,
        leadTimeRaw: '2 days',
        materialsCovered: 5,
      ),
    ];

    test('highlights lowest all-in, fastest lead, and most complete', () {
      final comparison = BidComparison.fromQuotes(quotes);

      expect(comparison.lowestTotalId, 'b'); // 9500 all-in
      expect(comparison.fastestLeadId, 'c'); // 2 days
      expect(comparison.mostCompleteId, 'b'); // 8 materials
    });

    test('summary mentions shop count and standouts', () {
      final lines = BidComparison.fromQuotes(quotes).summaryLines();

      expect(lines.first, contains('3 shops'));
      expect(lines.any((l) => l.contains('Beta Supply')), isTrue);
      expect(lines.any((l) => l.contains('QuickBuild')), isTrue);
    });

    test('single quote gets a simple snapshot line', () {
      final lines = BidComparison.fromQuotes([quotes.first]).summaryLines();
      expect(lines, hasLength(1));
      expect(lines.first, contains('only quotation'));
    });
  });

  group('parseQuotedLines', () {
    test('reads string names from availableMaterials', () {
      final lines = parseQuotedLines({
        'availableMaterials': ['Cement', 'Rebars'],
      });
      expect(lines.map((l) => l.name), ['Cement', 'Rebars']);
      expect(lines.every((l) => !l.hasPrice), isTrue);
    });

    test('reads priced maps from materials', () {
      final lines = parseQuotedLines({
        'materials': [
          {
            'name': 'Ceramic tiles',
            'quantity': 13,
            'unit': 'sqm',
            'unitPrice': 120,
            'subtotal': 1560,
          },
        ],
      });
      expect(lines, hasLength(1));
      expect(lines.single.unitPrice, 120);
      expect(lines.single.lineTotal, 1560);
      expect(lines.single.hasPrice, isTrue);
      expect(lines.single.quantityLabel, '13 sqm');
    });

    test('reads productName and price from shop payloads', () {
      final lines = parseQuotedLines({
        'materials': [
          {
            'category': 'Installation',
            'price': 22,
            'productName': 'Roofing sealant',
            'qty': 1,
            'size': '',
            'subtotal': 22,
            'unit': 'pcs',
          },
        ],
      });
      expect(lines, hasLength(1));
      expect(lines.single.name, 'Roofing sealant');
      expect(lines.single.unitPrice, 22);
      expect(lines.single.lineTotal, 22);
      expect(lines.single.hasPrice, isTrue);
    });

    test('reads a name-to-price map', () {
      final lines = parseQuotedLines({
        'prices': {'Floor Tiles': 180, 'Toilet': 2500},
      });
      expect(findQuotedLine(lines, 'floor tiles')?.unitPrice, 180);
      expect(findQuotedLine(lines, 'Toilet')?.unitPrice, 2500);
    });

    test('matches singular and plural names', () {
      final lines = parseQuotedLines({
        'items': [
          {'name': 'Floor Tile', 'unitPrice': 99, 'quantity': 20, 'unit': 'sqm'},
        ],
      });
      expect(findQuotedLine(lines, 'Floor Tiles')?.unitPrice, 99);
    });
  });

  group('findQuotedLine', () {
    test('matches ignoring case and extra spaces', () {
      const lines = [
        QuotedLine(name: 'Ceramic  Tiles', unitPrice: 120),
      ];
      expect(findQuotedLine(lines, 'ceramic tiles')?.unitPrice, 120);
    });
  });

  group('lowestPricedShopFor', () {
    test('picks the shop with the lowest unit price for an item', () {
      final quotes = [
        BidQuote.fromMap('a', {
          'shopName': 'Alpha',
          'estimatedTotal': 2000,
          'materials': [
            {'name': 'Cement', 'unitPrice': 280, 'quantity': 10},
          ],
        }),
        BidQuote.fromMap('b', {
          'shopName': 'Beta',
          'estimatedTotal': 1800,
          'materials': [
            {'name': 'Cement', 'unitPrice': 250, 'quantity': 10},
          ],
        }),
      ];
      expect(lowestPricedShopFor(quotes, 'Cement')?.id, 'b');
    });
  });

  group('bom coverage', () {
    final bom = const [
      QuotedLine(name: 'Roofing sealant', quantity: 1, unit: 'pcs'),
      QuotedLine(name: 'Roof paint', quantity: 3, unit: 'gal'),
    ];
    final giShop = BidQuote.fromMap('gi', {
      'shopName': 'GIShop',
      'estimatedTotal': 26,
      'materials': [
        {'productName': 'Roofing sealant', 'price': 22, 'qty': 1, 'unit': 'pcs'},
      ],
    });
    final other = BidQuote.fromMap('other', {
      'shopName': 'Other',
      'estimatedTotal': 172,
      'materials': [
        {'name': 'Roofing sealant', 'unitPrice': 22, 'quantity': 1},
        {'name': 'Roof paint', 'unitPrice': 50, 'quantity': 3, 'unit': 'gal'},
      ],
    });

    test('does not count a skipped item as covered', () {
      expect(bomCoverageCount(bom, giShop), 1);
      expect(bomCoverageCount(bom, other), 2);
      expect(unquotedBomItems(bom, giShop).single.name, 'Roof paint');
    });

    test('lists extra shop items that are not on the estimate', () {
      final extras = extraQuotedLines(bom, BidQuote.fromMap('x', {
        'shopName': 'Extra',
        'estimatedTotal': 10,
        'materials': [
          {'name': 'Roofing sealant', 'price': 22},
          {'name': 'Roofing screws', 'price': 2},
        ],
      }));
      expect(extras.map((l) => l.name), ['Roofing screws']);
    });

    test('suggests the shop that priced the skipped material', () {
      final advice = canvassAdvice(bom, [giShop, other]);
      expect(advice.suggestedShopId, 'other');
      expect(advice.headline, contains('Other'));
      expect(advice.detail, contains('GIShop'));
      expect(advice.detail, contains('Roof paint'));
      expect(
        advice.gaps.any(
          (gap) =>
              gap.materialName == 'Roof paint' &&
              gap.quotedByShop == 'Other' &&
              gap.missingFromShop == 'GIShop',
        ),
        isTrue,
      );
    });

    test('suggests the cheaper shop when both cover the list', () {
      final fullCheap = BidQuote.fromMap('cheap', {
        'shopName': 'Cheap',
        'estimatedTotal': 80,
        'materials': [
          {'name': 'Roofing sealant', 'price': 20, 'qty': 1},
          {'name': 'Roof paint', 'price': 60, 'qty': 3},
        ],
      });
      final fullDear = BidQuote.fromMap('dear', {
        'shopName': 'Dear',
        'estimatedTotal': 200,
        'materials': [
          {'name': 'Roofing sealant', 'price': 40, 'qty': 1},
          {'name': 'Roof paint', 'price': 160, 'qty': 3},
        ],
      });
      final advice = canvassAdvice(bom, [fullDear, fullCheap]);
      expect(advice.suggestedShopId, 'cheap');
      expect(advice.detail, contains('full estimate'));
    });
  });
}
