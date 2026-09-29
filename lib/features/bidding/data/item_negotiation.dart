/// Why a builder left a quoted line, and the shop's counter-offer on it.
///
/// A line left as "overpriced" is open to a lower price: the shop can send one
/// from the dashboard, and the builder takes it or turns it down here. The
/// shop writes the counter-offer; the builder only answers it. Kept free of
/// Firestore types, like the acceptance arithmetic it builds on.
library;

import 'package:iconstruct/features/bidding/data/partial_acceptance.dart';

/// A shop's counter-offer on one line, as the dashboard writes it.
class ItemNegotiation {
  /// The shop sends at most two offers on a line. After the second is turned
  /// down the line simply stays declined.
  static const int maxRounds = 2;

  static const String statusPending = 'pending';
  static const String statusAccepted = 'accepted';
  static const String statusDeclined = 'declined';

  /// The price the shop now asks: per unit on a line with a quantity, for the
  /// whole line otherwise. See [counterOfferIsPerUnit].
  final double shopOfferedPrice;
  final String status;
  final int round;

  const ItemNegotiation({
    required this.shopOfferedPrice,
    required this.status,
    required this.round,
  });

  bool get isPending => status == statusPending;
  bool get isAccepted => status == statusAccepted;
  bool get isDeclined => status == statusDeclined;

  /// Whether the shop may still send another offer after this one.
  bool get mayCounterAgain => round < maxRounds;

  /// The counter-offer on [item], or null when there is none or it carries no
  /// usable price.
  static ItemNegotiation? fromItem(Map<String, dynamic> item) {
    final raw = item['negotiation'];
    if (raw is! Map) return null;
    final price = _amount(raw['shopOfferedPrice']);
    if (price <= 0) return null;
    final status = '${raw['status'] ?? ''}'.trim().toLowerCase();
    final round = raw['round'];
    return ItemNegotiation(
      shopOfferedPrice: price,
      status: status.isEmpty ? statusPending : status,
      round: round is num ? round.toInt() : 1,
    );
  }
}

double _amount(Object? v) {
  if (v is num) return v.toDouble();
  return double.tryParse('${v ?? ''}'.replaceAll(',', '')) ?? 0;
}

double _quantityOf(Map<String, dynamic> item) =>
    _amount(item['quantity'] ?? item['qty']);

/// Whether a counter-offer on [item] is a price per unit.
///
/// Shops quote a line as a quantity at a unit price, "20 bags × ₱343", so a
/// new price on such a line is read the same way. A line quoted as one lump
/// has no unit to price, and the offer is the line's new total.
bool counterOfferIsPerUnit(Map<String, dynamic> item) =>
    _quantityOf(item) > 0 && _amount(item['unitPrice'] ?? item['price']) > 0;

/// The price the counter-offer replaces, in the same terms as the offer.
double priceBeforeCounterOffer(Map<String, dynamic> item) =>
    counterOfferIsPerUnit(item)
    ? _amount(item['unitPrice'] ?? item['price'])
    : lineTotalOf(item);

/// What the line comes to at [offeredPrice].
double lineTotalAtOffer(Map<String, dynamic> item, double offeredPrice) {
  final total = counterOfferIsPerUnit(item)
      ? offeredPrice * _quantityOf(item)
      : offeredPrice;
  return (total * 100).round() / 100;
}

/// [item] repriced at [offeredPrice].
///
/// Every price field the line already has is rewritten, so whichever one a
/// reader looks at, the builder app or the dashboard, gives the agreed figure.
Map<String, dynamic> repricedLine(
  Map<String, dynamic> item,
  double offeredPrice,
) {
  final perUnit = counterOfferIsPerUnit(item);
  final total = lineTotalAtOffer(item, offeredPrice);
  // A lone price on a line with no quantity is the line total, so it moves
  // with it. On a line with a quantity but no unit price it means nothing and
  // is left alone.
  final unitMoves = perUnit || _quantityOf(item) <= 0;
  final unitPrice = perUnit ? offeredPrice : total;
  return {
    ...item,
    if (unitMoves && item.containsKey('price')) 'price': unitPrice,
    if (unitMoves && item.containsKey('unitPrice')) 'unitPrice': unitPrice,
    'subtotal': total,
    if (item.containsKey('lineTotal')) 'lineTotal': total,
    if (item.containsKey('total')) 'total': total,
  };
}

/// Positions of the lines whose counter-offer is waiting on the builder.
List<int> pendingCounterOffers(List<Map<String, dynamic>> items) => [
  for (var i = 0; i < items.length; i++)
    if (ItemNegotiation.fromItem(items[i])?.isPending ?? false) i,
];

/// The quotation update when the builder answers the counter-offer on the
/// line at [index].
///
/// Taking it puts the line back in the order at the offered price. Turning it
/// down leaves the line out. Either way the negotiation records the answer,
/// and the total and status are worked out again from every line, the same
/// way the first acceptance was.
AcceptanceOutcome answerCounterOffer({
  required List<Map<String, dynamic>> items,
  required int index,
  required bool accept,
}) {
  if (index < 0 || index >= items.length) {
    throw RangeError.index(index, items, 'index');
  }
  final item = items[index];
  final negotiation = ItemNegotiation.fromItem(item);
  if (negotiation == null || !negotiation.isPending) {
    throw StateError('There is no counter-offer waiting on this line.');
  }

  final answered = {
    ...Map<String, dynamic>.from(item['negotiation'] as Map),
    'status': accept
        ? ItemNegotiation.statusAccepted
        : ItemNegotiation.statusDeclined,
  };
  final updated = [
    for (var i = 0; i < items.length; i++)
      if (i != index)
        items[i]
      else if (accept)
        {
          ...repricedLine(item, negotiation.shopOfferedPrice),
          'negotiation': answered,
        }
      else
        {...item, 'negotiation': answered},
  ];

  return resolveAcceptance(
    items: updated,
    acceptedIndexes: {
      for (var i = 0; i < updated.length; i++)
        if (i == index ? accept : updated[i]['accepted'] != false) i,
    },
  );
}
