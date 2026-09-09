/// Per-line acceptance of a shop's quotation.
///
/// A builder canvassing across several hardware shops rarely wants one shop's
/// whole list. Cement may be cheapest at one supplier and tile at another, so
/// the estimate is only useful if each line can be taken or left. This turns a
/// set of ticked lines into exactly what gets written back to the quotation.
///
/// Kept free of Firestore types so the arithmetic and the status rule can be
/// tested directly; the service does the writing.
library;

/// What a builder's line selection resolves to on the quotation document.
class AcceptanceOutcome {
  /// `accepted` when every priced line was kept, `partially_accepted` when
  /// some were dropped. A quotation with nothing ticked is not an acceptance
  /// at all and is rejected before reaching here.
  final String status;

  /// The quotation's `items` array with an `accepted` flag written onto each
  /// entry. The array is rewritten whole because Firestore cannot address a
  /// single element of an array.
  final List<Map<String, dynamic>> items;

  /// Sum of the lines the builder kept.
  final double acceptedTotal;

  /// How many lines were kept, for the confirmation copy.
  final int acceptedCount;

  /// How many lines the shop quoted in total.
  final int totalCount;

  const AcceptanceOutcome({
    required this.status,
    required this.items,
    required this.acceptedTotal,
    required this.acceptedCount,
    required this.totalCount,
  });

  bool get isPartial => status == statusPartiallyAccepted;

  static const String statusAccepted = 'accepted';
  static const String statusPartiallyAccepted = 'partially_accepted';
}

/// Line total for one quoted item, mirroring `QuotedLine.lineTotal`.
///
/// A shop may send a subtotal, or a unit price and quantity, or only a unit
/// price. Reading them in that order keeps the builder's total consistent with
/// the figure shown beside each line.
double lineTotalOf(Map<String, dynamic> item) {
  double amount(Object? v) {
    if (v is num) return v.toDouble();
    return double.tryParse('${v ?? ''}'.replaceAll(',', '')) ?? 0;
  }

  final subtotal =
      amount(item['subtotal'] ?? item['lineTotal'] ?? item['total']);
  if (subtotal > 0) return subtotal;

  final unitPrice = amount(item['unitPrice'] ?? item['price']);
  final quantity = amount(item['quantity'] ?? item['qty']);
  if (unitPrice > 0 && quantity > 0) return unitPrice * quantity;
  return unitPrice;
}

/// Resolves a builder's ticked lines into the document update.
///
/// [acceptedIndexes] holds the positions the builder left ticked. Passing null
/// means every line was kept, which is the plain full acceptance the app had
/// before per-line choice existed.
AcceptanceOutcome resolveAcceptance({
  required List<Map<String, dynamic>> items,
  Set<int>? acceptedIndexes,
}) {
  final keptAll = acceptedIndexes == null;
  final out = <Map<String, dynamic>>[];
  var total = 0.0;
  var kept = 0;

  for (var i = 0; i < items.length; i++) {
    final accepted = keptAll || acceptedIndexes.contains(i);
    // Copy rather than mutate: the caller's list came from a snapshot and is
    // reused to render the screen behind the confirmation sheet.
    out.add({...items[i], 'accepted': accepted});
    if (accepted) {
      kept++;
      total += lineTotalOf(items[i]);
    }
  }

  // Round to centavos. Repeated addition of unit-price products otherwise
  // leaves a total like 12449.999999999998 on the document.
  total = (total * 100).round() / 100;

  return AcceptanceOutcome(
    status: kept == items.length
        ? AcceptanceOutcome.statusAccepted
        : AcceptanceOutcome.statusPartiallyAccepted,
    items: out,
    acceptedTotal: total,
    acceptedCount: kept,
    totalCount: items.length,
  );
}

/// Reads a quotation's line items out of the shapes shops actually send.
///
/// The web dashboard and older clients disagree on the field name, so the
/// first list that looks like line items wins.
List<Map<String, dynamic>> quotationItems(Map<String, dynamic> data) {
  const keys = [
    'items',
    'materials',
    'lineItems',
    'quotedItems',
    'quotedMaterials',
  ];
  for (final key in keys) {
    final raw = data[key];
    if (raw is List && raw.isNotEmpty) {
      return raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
  }
  return const [];
}
