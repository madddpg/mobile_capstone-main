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
  /// some were dropped. Unavailable lines were never on offer, so they do not
  /// make an acceptance partial. A quotation with nothing ticked is not an
  /// acceptance at all and is rejected before reaching here.
  final String status;

  /// The quotation's `items` array with an `accepted` flag written onto each
  /// entry. The array is rewritten whole because Firestore cannot address a
  /// single element of an array.
  final List<Map<String, dynamic>> items;

  /// Sum of the lines the builder kept.
  final double acceptedTotal;

  /// How many lines were kept, for the confirmation copy.
  final int acceptedCount;

  /// How many lines the shop quoted in total, not counting unavailable ones.
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

  final subtotal = amount(
    item['subtotal'] ?? item['lineTotal'] ?? item['total'],
  );
  if (subtotal > 0) return subtotal;

  final unitPrice = amount(item['unitPrice'] ?? item['price']);
  final quantity = amount(item['quantity'] ?? item['qty']);
  if (unitPrice > 0 && quantity > 0) return unitPrice * quantity;
  return unitPrice;
}

/// Statuses the shop dashboard uses for a line it cannot supply, compared
/// with spaces, underscores and hyphens taken out.
const _unavailableStatuses = {'unavailable', 'notavailable', 'outofstock'};

/// Whether the shop marked this line as one it cannot supply, whatever price
/// the line still carries.
bool isMarkedUnavailable(Map<String, dynamic> item) {
  final status = '${item['status'] ?? ''}'.trim().toLowerCase().replaceAll(
    RegExp(r'[\s_-]+'),
    '',
  );
  return _unavailableStatuses.contains(status) || item['available'] == false;
}

/// Whether the shop cannot supply this line: marked unavailable, or sent with
/// no price, which is the same answer.
///
/// Such a line is not an offer. It is shown as "Unavailable", as the shop
/// dashboard shows it, cannot be taken, and is never counted as a line the
/// builder chose to leave, so the builder is never asked why.
bool isUnavailableLine(Map<String, dynamic> item) =>
    isMarkedUnavailable(item) || lineTotalOf(item) <= 0;

/// Why the builder did not take a line. Written as `declineReason` on the
/// line, and only on lines the builder left.
enum DeclineReason {
  notNeeded('not_needed', 'Not needed'),

  /// Tells the shop the line is open to a lower counter-price.
  overpriced('overpriced', 'Overpriced');

  /// The value stored on the line.
  final String value;
  final String label;

  const DeclineReason(this.value, this.label);

  static DeclineReason? fromValue(Object? raw) {
    final value = '${raw ?? ''}'.trim().toLowerCase();
    for (final reason in DeclineReason.values) {
      if (reason.value == value) return reason;
    }
    return null;
  }
}

/// The reason stored on a line, if the builder gave one.
DeclineReason? declineReasonOf(Map<String, dynamic> item) =>
    DeclineReason.fromValue(item['declineReason']);

/// Resolves a builder's ticked lines into the document update.
///
/// [acceptedIndexes] holds the positions the builder left ticked. Passing null
/// means every line was kept, which is the plain full acceptance the app had
/// before per-line choice existed.
///
/// [declineReasons], keyed by position, says why a line was left. When given,
/// each left line carries its reason and no other line carries one, so a
/// reason from an earlier acceptance of the same quotation cannot linger.
/// When null, whatever reasons the lines already have are kept, which is what
/// answering a counter-offer needs.
///
/// An unavailable line is never taken, whatever the selection says, and never
/// carries a reason: the shop did not offer it, so the builder did not leave
/// it.
AcceptanceOutcome resolveAcceptance({
  required List<Map<String, dynamic>> items,
  Set<int>? acceptedIndexes,
  Map<int, DeclineReason>? declineReasons,
}) {
  final keptAll = acceptedIndexes == null;
  final out = <Map<String, dynamic>>[];
  var total = 0.0;
  var kept = 0;
  var offered = 0;

  for (var i = 0; i < items.length; i++) {
    final unavailable = isUnavailableLine(items[i]);
    if (!unavailable) offered++;
    final accepted = !unavailable && (keptAll || acceptedIndexes.contains(i));
    // Copy rather than mutate: the caller's list came from a snapshot and is
    // reused to render the screen behind the confirmation sheet.
    final line = {...items[i], 'accepted': accepted};
    if (declineReasons != null || unavailable) {
      final reason = accepted || unavailable ? null : declineReasons?[i];
      if (reason == null) {
        line.remove('declineReason');
      } else {
        line['declineReason'] = reason.value;
      }
    }
    out.add(line);
    if (accepted) {
      kept++;
      total += lineTotalOf(items[i]);
    }
  }

  // Round to centavos. Repeated addition of unit-price products otherwise
  // leaves a total like 12449.999999999998 on the document.
  total = (total * 100).round() / 100;

  return AcceptanceOutcome(
    status: kept == offered
        ? AcceptanceOutcome.statusAccepted
        : AcceptanceOutcome.statusPartiallyAccepted,
    items: out,
    acceptedTotal: total,
    acceptedCount: kept,
    totalCount: offered,
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

/// The name on a quoted or estimated line, from whichever field holds it.
/// Empty when the line has none.
///
/// The shop dashboard is a separate app and its lines have arrived under every
/// one of these spellings. Every screen that shows a quoted line reads the name
/// through here, so a shape one screen understands is never a blank on another.
String quotedItemName(Map<String, dynamic> item) {
  return (item['name'] ??
          item['material'] ??
          item['materialName'] ??
          item['productName'] ??
          item['itemName'] ??
          item['product'] ??
          item['item'] ??
          item['description'] ??
          '')
      .toString()
      .trim();
}

/// Whether the shop quoted its own product in place of the one asked for.
///
/// The shop dashboard marks such a line `status: "substituted"` and keeps the
/// builder's material in `requestedName`, with the shop's product as the name.
/// A line that names a different requested material is read the same way even
/// without the status, so a dashboard that forgets the flag still reads right.
bool isSubstitutedLine(Map<String, dynamic> item) {
  final status = '${item['status'] ?? ''}'.trim().toLowerCase();
  if (status == 'substituted' || status == 'substitute') return true;
  final requested = '${item['requestedName'] ?? ''}'.trim().toLowerCase();
  return requested.isNotEmpty &&
      requested != quotedItemName(item).toLowerCase();
}

/// The builder's material a quoted line answers: the requested one for a
/// substitute, otherwise the line's own name.
String requestedItemName(Map<String, dynamic> item) {
  if (isSubstitutedLine(item)) {
    final requested = '${item['requestedName'] ?? ''}'.trim();
    if (requested.isNotEmpty) return requested;
  }
  return quotedItemName(item);
}

/// The shop's note on one line, such as why it was substituted.
String quotedLineNote(Map<String, dynamic> item) =>
    '${item['lineNote'] ?? item['note'] ?? ''}'.trim();

/// What a builder took and left on a quotation, read back from the document.
class AcceptanceSummary {
  /// Lines the builder took from this shop.
  final List<Map<String, dynamic>> kept;

  /// Lines the builder left, to buy elsewhere.
  final List<Map<String, dynamic>> dropped;

  /// Lines the shop cannot supply. Neither taken nor left: never on offer.
  final List<Map<String, dynamic>> unavailable;

  /// What the kept lines come to.
  final double keptTotal;

  const AcceptanceSummary({
    required this.kept,
    required this.dropped,
    required this.keptTotal,
    this.unavailable = const [],
  });

  /// Lines the shop offered, which is what "took 3 of 5" counts.
  int get totalCount => kept.length + dropped.length;

  bool get isPartial => kept.isNotEmpty && dropped.isNotEmpty;
}

/// Reads which lines of an accepted quotation the builder kept.
///
/// The per-line `accepted` flags are written by the builder's acceptance, so
/// they only mean something on a quotation marked `partially_accepted`. On any
/// other quotation every line counts as kept, whatever flags the document
/// carries: a shop could have put them on its own open offer.
AcceptanceSummary readAcceptance(Map<String, dynamic> data) {
  final partial =
      (data['status'] ?? '').toString().trim().toLowerCase() ==
      AcceptanceOutcome.statusPartiallyAccepted;

  final kept = <Map<String, dynamic>>[];
  final dropped = <Map<String, dynamic>>[];
  final unavailable = <Map<String, dynamic>>[];
  for (final item in quotationItems(data)) {
    if (isUnavailableLine(item)) {
      unavailable.add(item);
    } else if (partial && item['accepted'] == false) {
      dropped.add(item);
    } else {
      kept.add(item);
    }
  }

  final stored = data['acceptedTotal'];
  var keptTotal = partial && stored is num
      ? stored.toDouble()
      : kept.fold<double>(0, (sum, item) => sum + lineTotalOf(item));
  keptTotal = (keptTotal * 100).round() / 100;

  return AcceptanceSummary(
    kept: kept,
    dropped: dropped,
    unavailable: unavailable,
    keptTotal: keptTotal,
  );
}
