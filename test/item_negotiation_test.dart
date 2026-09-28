import 'package:flutter_test/flutter_test.dart';

import 'package:iconstruct/features/bidding/data/item_negotiation.dart';
import 'package:iconstruct/features/bidding/data/partial_acceptance.dart';

/// A line left as overpriced can come back from the shop at a lower price.
/// The builder takes it, and the line rejoins the order at that price, or
/// turns it down, and the line stays out.

/// 20 bags at ₱343, as the dashboard writes a line.
Map<String, dynamic> _cement({Map<String, dynamic>? negotiation}) => {
  'productName': 'Portland Cement (40 kg)',
  'qty': 20,
  'unit': 'bags',
  'price': 343,
  'subtotal': 6860,
  'accepted': false,
  'declineReason': 'overpriced',
  if (negotiation != null) 'negotiation': negotiation,
};

Map<String, dynamic> _paint() => {
  'productName': 'Interior Latex Paint (4 L)',
  'qty': 4,
  'unit': 'gal',
  'price': 10,
  'subtotal': 40,
  'accepted': true,
};

Map<String, dynamic> _offer(
  num price, {
  String status = 'pending',
  int round = 1,
}) => {'shopOfferedPrice': price, 'status': status, 'round': round};

void main() {
  group('decline reasons', () {
    test('are written only on the lines left', () {
      final outcome = resolveAcceptance(
        items: [_paint(), _cement()..remove('declineReason')],
        acceptedIndexes: {0},
        declineReasons: {1: DeclineReason.overpriced},
      );
      expect(outcome.items[0].containsKey('declineReason'), isFalse);
      expect(outcome.items[1]['declineReason'], 'overpriced');
    });

    test('a left line with no reason carries none', () {
      final outcome = resolveAcceptance(
        items: [_paint(), _cement()..remove('declineReason')],
        acceptedIndexes: {0},
        declineReasons: const {},
      );
      expect(outcome.items[1].containsKey('declineReason'), isFalse);
    });

    test('a reason given for a kept line is ignored', () {
      final outcome = resolveAcceptance(
        items: [_paint(), _cement()],
        acceptedIndexes: {0, 1},
        declineReasons: {1: DeclineReason.notNeeded},
      );
      expect(outcome.items[1].containsKey('declineReason'), isFalse);
    });

    test('a reason from an earlier acceptance does not linger', () {
      final outcome = resolveAcceptance(
        items: [_paint(), _cement()],
        acceptedIndexes: {0, 1},
        declineReasons: const {},
      );
      expect(outcome.items[1].containsKey('declineReason'), isFalse);
    });

    test('are left as they are when none are given', () {
      final outcome = resolveAcceptance(
        items: [_paint(), _cement()],
        acceptedIndexes: {0},
      );
      expect(outcome.items[1]['declineReason'], 'overpriced');
    });

    test('read back from the stored value', () {
      expect(DeclineReason.fromValue('not_needed'), DeclineReason.notNeeded);
      expect(DeclineReason.fromValue('overpriced'), DeclineReason.overpriced);
      expect(DeclineReason.fromValue('cheaper elsewhere'), isNull);
      expect(declineReasonOf(_cement()), DeclineReason.overpriced);
    });
  });

  group('reading a counter-offer', () {
    test('a line without one has none', () {
      expect(ItemNegotiation.fromItem(_paint()), isNull);
    });

    test('reads the price, status and round', () {
      final n = ItemNegotiation.fromItem(_cement(negotiation: _offer(300)))!;
      expect(n.shopOfferedPrice, 300);
      expect(n.isPending, isTrue);
      expect(n.round, 1);
      expect(n.mayCounterAgain, isTrue);
    });

    test('the second round is the last', () {
      final n = ItemNegotiation.fromItem(
        _cement(negotiation: _offer(290, status: 'declined', round: 2)),
      )!;
      expect(n.mayCounterAgain, isFalse);
    });

    test('an offer with no usable price is ignored', () {
      expect(ItemNegotiation.fromItem(_cement(negotiation: _offer(0))), isNull);
    });

    test('finds the lines waiting on the builder', () {
      final items = [
        _paint(),
        _cement(negotiation: _offer(300)),
        _cement(negotiation: _offer(300, status: 'declined')),
      ];
      expect(pendingCounterOffers(items), [1]);
    });
  });

  group('the offered price', () {
    test('is per unit on a line quoted by quantity', () {
      final line = _cement();
      expect(counterOfferIsPerUnit(line), isTrue);
      expect(priceBeforeCounterOffer(line), 343);
      expect(lineTotalAtOffer(line, 300), 6000);
    });

    test('is the whole line on a lump-sum line', () {
      final line = {'productName': 'Delivery', 'subtotal': 1500};
      expect(counterOfferIsPerUnit(line), isFalse);
      expect(priceBeforeCounterOffer(line), 1500);
      expect(lineTotalAtOffer(line, 1200), 1200);
    });

    test('rewrites every price field the line has', () {
      final repriced = repricedLine({
        ..._cement(),
        'unitPrice': 343,
        'lineTotal': 6860,
      }, 300);
      expect(repriced['price'], 300);
      expect(repriced['unitPrice'], 300);
      expect(repriced['subtotal'], 6000);
      expect(repriced['lineTotal'], 6000);
      expect(lineTotalOf(repriced), 6000);
    });

    test('adds no price field the line did not have', () {
      final repriced = repricedLine(_cement(), 300);
      expect(repriced.containsKey('unitPrice'), isFalse);
      expect(repriced.containsKey('lineTotal'), isFalse);
    });
  });

  group('answering a counter-offer', () {
    List<Map<String, dynamic>> items() => [
      _paint(),
      _cement(negotiation: _offer(300)),
    ];

    test('taking it puts the line back at the offered price', () {
      final outcome = answerCounterOffer(
        items: items(),
        index: 1,
        accept: true,
      );
      final line = outcome.items[1];
      expect(line['accepted'], isTrue);
      expect(line['price'], 300);
      expect(line['subtotal'], 6000);
      expect((line['negotiation'] as Map)['status'], 'accepted');
      // ₱40 of paint plus the cement at the new price.
      expect(outcome.acceptedTotal, 6040);
      expect(outcome.status, AcceptanceOutcome.statusAccepted);
    });

    test('turning it down leaves the line out at its old price', () {
      final outcome = answerCounterOffer(
        items: items(),
        index: 1,
        accept: false,
      );
      final line = outcome.items[1];
      expect(line['accepted'], isFalse);
      expect(line['subtotal'], 6860);
      expect((line['negotiation'] as Map)['status'], 'declined');
      expect(outcome.acceptedTotal, 40);
      expect(outcome.status, AcceptanceOutcome.statusPartiallyAccepted);
    });

    test('keeps the offer itself and the reason on the line', () {
      final outcome = answerCounterOffer(
        items: items(),
        index: 1,
        accept: true,
      );
      final negotiation = outcome.items[1]['negotiation'] as Map;
      expect(negotiation['shopOfferedPrice'], 300);
      expect(negotiation['round'], 1);
      expect(outcome.items[1]['declineReason'], 'overpriced');
    });

    test('other lines are untouched', () {
      final before = items();
      final outcome = answerCounterOffer(items: before, index: 1, accept: true);
      expect(outcome.items[0]['subtotal'], 40);
      expect(outcome.items[0]['accepted'], isTrue);
      // The caller's list is not mutated.
      expect(before[1]['accepted'], isFalse);
    });

    test('an offer already answered cannot be answered again', () {
      expect(
        () => answerCounterOffer(
          items: [
            _paint(),
            _cement(negotiation: _offer(300, status: 'declined')),
          ],
          index: 1,
          accept: true,
        ),
        throwsStateError,
      );
    });

    test('a line with no offer cannot be answered', () {
      expect(
        () => answerCounterOffer(items: items(), index: 0, accept: true),
        throwsStateError,
      );
    });
  });
}
