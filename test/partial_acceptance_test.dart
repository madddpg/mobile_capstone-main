import 'package:flutter_test/flutter_test.dart';
import 'package:iconstruct/features/bidding/data/partial_acceptance.dart';

/// Per-line acceptance decides what a shop is told it won, and what the builder
/// believes they owe. Both have to be right.
void main() {
  List<Map<String, dynamic>> lines() => [
    {
      'name': 'Portland Cement',
      'quantity': 18,
      'unit': 'bags',
      'unitPrice': 260,
    },
    {'name': 'Floor Tiles', 'quantity': 60, 'unit': 'pcs', 'subtotal': 4500},
    {'name': 'Tile Adhesive', 'quantity': 4, 'unit': 'bags', 'unitPrice': 320},
  ];

  group('lineTotalOf', () {
    test('a stated subtotal wins over unit price', () {
      expect(
        lineTotalOf({'subtotal': 4500, 'unitPrice': 10, 'quantity': 2}),
        4500,
      );
    });

    test('unit price times quantity when there is no subtotal', () {
      expect(lineTotalOf({'unitPrice': 260, 'quantity': 18}), 4680);
    });

    test('a lone unit price is used as the line total', () {
      expect(lineTotalOf({'unitPrice': 750}), 750);
    });

    test('prices arriving as strings with separators still parse', () {
      // Web dashboards submit form values as text often enough to matter.
      expect(lineTotalOf({'subtotal': '1,250.50'}), 1250.5);
    });

    test('a line with no price at all is zero, not an error', () {
      expect(lineTotalOf({'name': 'Tie wire'}), 0);
    });
  });

  group('resolveAcceptance', () {
    test('keeping every line is a plain acceptance', () {
      final out = resolveAcceptance(items: lines(), acceptedIndexes: {0, 1, 2});
      expect(out.status, 'accepted');
      expect(out.isPartial, isFalse);
      expect(out.acceptedCount, 3);
      expect(out.items.every((i) => i['accepted'] == true), isTrue);
      expect(out.acceptedTotal, 4680 + 4500 + 1280);
    });

    test('a null selection accepts everything', () {
      // The path used before per-line choice existed, and by lump-sum quotes.
      final out = resolveAcceptance(items: lines());
      expect(out.status, 'accepted');
      expect(out.acceptedCount, 3);
    });

    test('dropping a line marks the quotation partially accepted', () {
      final out = resolveAcceptance(items: lines(), acceptedIndexes: {0, 2});
      expect(out.status, 'partially_accepted');
      expect(out.isPartial, isTrue);
      expect(out.acceptedCount, 2);
      expect(out.totalCount, 3);
      expect(out.acceptedTotal, 4680 + 1280);
    });

    test('every line carries an explicit accepted flag, kept or not', () {
      // The shop reads this array to see what it actually won, so a dropped
      // line must say false rather than simply lack the field.
      final out = resolveAcceptance(items: lines(), acceptedIndexes: {1});
      expect(out.items[0]['accepted'], isFalse);
      expect(out.items[1]['accepted'], isTrue);
      expect(out.items[2]['accepted'], isFalse);
    });

    test('the original line data survives untouched', () {
      final out = resolveAcceptance(items: lines(), acceptedIndexes: {0});
      expect(out.items[0]['name'], 'Portland Cement');
      expect(out.items[0]['quantity'], 18);
      expect(out.items[0]['unitPrice'], 260);
    });

    test('the caller\'s list is not mutated', () {
      final original = lines();
      resolveAcceptance(items: original, acceptedIndexes: {0});
      expect(original[0].containsKey('accepted'), isFalse);
    });

    test('the total is rounded to centavos', () {
      // Repeated addition of unit-price products otherwise writes something
      // like 12449.999999999998 onto the document.
      final out = resolveAcceptance(
        items: [
          {'unitPrice': 33.33, 'quantity': 3},
          {'unitPrice': 66.67, 'quantity': 3},
        ],
      );
      expect(out.acceptedTotal, 300.0);
    });
  });

  group('quotationItems', () {
    test('reads the items array', () {
      final items = quotationItems({
        'items': [
          {'name': 'Cement'},
        ],
      });
      expect(items.single['name'], 'Cement');
    });

    test('falls back to the other names shops send', () {
      for (final key in ['materials', 'lineItems', 'quotedItems']) {
        final items = quotationItems({
          key: [
            {'name': 'Cement'},
          ],
        });
        expect(items.length, 1, reason: 'did not read $key');
      }
    });

    test('a quotation with no lines returns empty, not null', () {
      expect(quotationItems({'estimatedTotal': 5000}), isEmpty);
    });
  });

  // Every screen showing a quoted line reads its name through quotedItemName.
  // A line the bids screen could name used to read as "Unnamed item" on the
  // select-shop checklist, which had its own shorter list of fields.
  group('the name on a quoted line', () {
    test('is read from every field a shop has sent it under', () {
      const fields = [
        'name',
        'material',
        'materialName',
        'productName',
        'itemName',
        'product',
        'item',
        'description',
      ];
      for (final field in fields) {
        expect(
          quotedItemName({field: 'Portland Cement 40kg'}),
          'Portland Cement 40kg',
          reason: 'did not read $field',
        );
      }
    });

    test('prefers the plainest field when a line carries several', () {
      expect(
        quotedItemName({
          'name': 'Portland Cement 40kg',
          'description': 'Grey bag, delivered',
        }),
        'Portland Cement 40kg',
      );
    });

    test('is empty when the line truly has none', () {
      expect(quotedItemName({'unitPrice': 250, 'quantity': 4}), isEmpty);
    });
  });

  // A line the shop cannot supply is not an offer. The builder never took it
  // and never left it, so it is never asked about and never makes an
  // acceptance partial.
  group('an unavailable line', () {
    Map<String, dynamic> roofPaint() => {
      'name': 'Roof Paint',
      'quantity': 2,
      'unit': 'gal',
      'status': 'unavailable',
    };

    test('is one the shop marked unavailable, however it spells it', () {
      for (final status in [
        'unavailable',
        'Unavailable',
        'not_available',
        'Out of stock',
      ]) {
        expect(
          isUnavailableLine({
            'name': 'Roof Paint',
            'unitPrice': 900,
            'status': status,
          }),
          isTrue,
          reason: status,
        );
      }
      expect(
        isUnavailableLine({
          'name': 'Roof Paint',
          'unitPrice': 900,
          'available': false,
        }),
        isTrue,
      );
    });

    test('is one sent with no price, which is the same answer', () {
      expect(isUnavailableLine({'name': 'Roof Paint', 'quantity': 2}), isTrue);
    });

    test('is not a priced line, nor a substitute', () {
      expect(isUnavailableLine(lines().first), isFalse);
      expect(
        isUnavailableLine({
          'name': 'laway',
          'price': 343,
          'qty': 20,
          'status': 'substituted',
        }),
        isFalse,
      );
    });

    test('is never taken, whatever the selection says', () {
      final out = resolveAcceptance(
        items: [...lines(), roofPaint()],
        acceptedIndexes: {0, 1, 2, 3},
      );
      expect(out.items[3]['accepted'], isFalse);
    });

    test('does not make taking every offered line partial', () {
      final out = resolveAcceptance(
        items: [...lines(), roofPaint()],
        acceptedIndexes: {0, 1, 2},
      );
      expect(out.status, 'accepted');
      expect(out.acceptedCount, 3);
      expect(out.totalCount, 3);
    });

    test('never carries a reason', () {
      final out = resolveAcceptance(
        items: [
          ...lines(),
          {...roofPaint(), 'declineReason': 'overpriced'},
        ],
        acceptedIndexes: {0, 1, 2},
        declineReasons: {3: DeclineReason.overpriced},
      );
      expect(out.items[3].containsKey('declineReason'), isFalse);
    });

    test('is read back apart from the lines taken and left', () {
      final summary = readAcceptance({
        'status': 'partially_accepted',
        'items': [
          {...lines()[0], 'accepted': true},
          {...lines()[1], 'accepted': false},
          {...roofPaint(), 'accepted': false},
        ],
      });
      expect(summary.kept.single['name'], 'Portland Cement');
      expect(summary.dropped.single['name'], 'Floor Tiles');
      expect(summary.unavailable.single['name'], 'Roof Paint');
      expect(summary.totalCount, 2);
    });

    test('is not counted as taken on a plain acceptance', () {
      final summary = readAcceptance({
        'status': 'accepted',
        'items': [lines()[0], roofPaint()],
      });
      expect(summary.kept, hasLength(1));
      expect(summary.unavailable, hasLength(1));
      expect(summary.isPartial, isFalse);
    });
  });
}
