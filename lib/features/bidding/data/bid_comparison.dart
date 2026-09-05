/// Rules-based comparison of private shop quotations for a builder.
///
/// Catalog list prices stay out of this — we only rank the quotes each shop
/// submitted for the builder's posted estimate.
library;

double bidAsDouble(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString()) ?? 0;
}

String normalizeMaterialName(String raw) {
  var text = raw.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ');
  text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  return text;
}

String _stemMaterialName(String raw) {
  final words = normalizeMaterialName(raw).split(' ').where((w) => w.isNotEmpty);
  return words
      .map((word) {
        if (word.length > 3 && word.endsWith('s')) {
          return word.substring(0, word.length - 1);
        }
        return word;
      })
      .join(' ');
}

List<QuotedLine> _linesFromRaw(dynamic raw) {
  if (raw is Map) {
    final lines = <QuotedLine>[];
    raw.forEach((key, value) {
      final name = key.toString().trim();
      if (name.isEmpty) return;
      if (value is num || value is String) {
        final price = bidAsDouble(value);
        if (price <= 0) {
          lines.add(QuotedLine(name: name));
          return;
        }
        lines.add(QuotedLine(name: name, unitPrice: price, subtotal: price));
        return;
      }
      if (value is Map) {
        final map = Map<String, dynamic>.from(value);
        map.putIfAbsent('name', () => name);
        lines.addAll(_linesFromRaw([map]));
      }
    });
    return lines;
  }
  if (raw is! List) return const [];

  final lines = <QuotedLine>[];
  for (final item in raw) {
    if (item is String) {
      final name = item.trim();
      if (name.isNotEmpty) lines.add(QuotedLine(name: name));
      continue;
    }
    if (item is! Map) continue;
    final map = Map<String, dynamic>.from(item);
    final name = (map['name'] ??
            map['productName'] ??
            map['materialName'] ??
            map['itemName'] ??
            map['material'] ??
            map['product'] ??
            map['item'] ??
            '')
        .toString()
        .trim();
    if (name.isEmpty) continue;
    final quantity = bidAsDouble(map['quantity'] ?? map['qty']);
    final unitPrice = bidAsDouble(
      map['unitPrice'] ??
          map['price'] ??
          map['unit_price'] ??
          map['quotedPrice'] ??
          map['offerPrice'],
    );
    var subtotal = bidAsDouble(
      map['subtotal'] ?? map['amount'] ?? map['lineTotal'] ?? map['total'],
    );
    if (subtotal <= 0 && unitPrice > 0 && quantity > 0) {
      subtotal = unitPrice * quantity;
    }
    lines.add(
      QuotedLine(
        name: name,
        quantity: quantity,
        unit: (map['unit'] ?? '').toString(),
        size: (map['size'] ?? '').toString(),
        unitPrice: unitPrice,
        subtotal: subtotal,
      ),
    );
  }
  return lines;
}

List<QuotedLine> _mergeQuotedLines(List<QuotedLine> incoming) {
  final byName = <String, QuotedLine>{};
  for (final line in incoming) {
    final key = _stemMaterialName(line.name);
    if (key.isEmpty) continue;
    final existing = byName[key];
    if (existing == null) {
      byName[key] = line;
      continue;
    }
    byName[key] = QuotedLine(
      name: existing.hasPrice ? existing.name : line.name,
      quantity: existing.quantity > 0 ? existing.quantity : line.quantity,
      unit: existing.unit.trim().isNotEmpty ? existing.unit : line.unit,
      size: existing.size.trim().isNotEmpty ? existing.size : line.size,
      unitPrice: existing.unitPrice > 0 ? existing.unitPrice : line.unitPrice,
      subtotal: existing.subtotal > 0 ? existing.subtotal : line.subtotal,
    );
  }
  return byName.values.toList();
}

/// Reads shop line items from common quotation payloads.
List<QuotedLine> parseQuotedLines(Map<String, dynamic> data) {
  const keys = [
    'materials',
    'lineItems',
    'items',
    'quotedItems',
    'quotedMaterials',
    'products',
    'quotes',
    'materialQuotes',
    'availableMaterials',
    'prices',
    'unitPrices',
    'itemPrices',
    'materialPrices',
  ];

  final collected = <QuotedLine>[];
  for (final key in keys) {
    if (!data.containsKey(key)) continue;
    collected.addAll(_linesFromRaw(data[key]));
  }
  return _mergeQuotedLines(collected);
}

/// One priced (or unpriced) material line from a shop quotation or BOM.
class QuotedLine {
  final String name;
  final double quantity;
  final String unit;
  final String size;
  final double unitPrice;
  final double subtotal;

  const QuotedLine({
    required this.name,
    this.quantity = 0,
    this.unit = '',
    this.size = '',
    this.unitPrice = 0,
    this.subtotal = 0,
  });

  bool get hasPrice => unitPrice > 0 || subtotal > 0;

  double get lineTotal {
    if (subtotal > 0) return subtotal;
    if (unitPrice > 0 && quantity > 0) return unitPrice * quantity;
    return unitPrice;
  }

  String get quantityLabel {
    if (quantity <= 0) return '';
    final qty = quantity == quantity.roundToDouble()
        ? quantity.toStringAsFixed(0)
        : quantity.toStringAsFixed(2);
    return unit.trim().isEmpty ? qty : '$qty $unit';
  }

  double get derivedUnitPrice {
    if (unitPrice > 0) return unitPrice;
    if (subtotal > 0 && quantity > 0) return subtotal / quantity;
    return 0;
  }
}

QuotedLine? findQuotedLine(List<QuotedLine> lines, String materialName) {
  final target = normalizeMaterialName(materialName);
  final targetStem = _stemMaterialName(materialName);
  if (target.isEmpty) return null;
  for (final line in lines) {
    if (normalizeMaterialName(line.name) == target) return line;
  }
  for (final line in lines) {
    if (_stemMaterialName(line.name) == targetStem) return line;
  }
  for (final line in lines) {
    final name = normalizeMaterialName(line.name);
    if (name.contains(target) || target.contains(name)) return line;
  }
  return null;
}

/// Prefer unit price when shops quote the same item; otherwise line total.
double quotedComparePrice(QuotedLine line) {
  if (line.unitPrice > 0) return line.unitPrice;
  return line.lineTotal;
}

BidQuote? lowestPricedShopFor(List<BidQuote> quotes, String materialName) {
  BidQuote? best;
  double? bestPrice;
  for (final quote in quotes) {
    final line = findQuotedLine(quote.lines, materialName);
    if (line == null || !line.hasPrice) continue;
    final price = quotedComparePrice(line);
    if (bestPrice == null || price < bestPrice) {
      best = quote;
      bestPrice = price;
    }
  }
  return best;
}

/// How many estimate lines this shop actually priced. Missing is not ₱0.
int bomCoverageCount(List<QuotedLine> bom, BidQuote quote) {
  if (bom.isEmpty) return quote.lines.where((line) => line.hasPrice).length;
  var count = 0;
  for (final item in bom) {
    final line = findQuotedLine(quote.lines, item.name);
    if (line != null && line.hasPrice) count++;
  }
  return count;
}

List<QuotedLine> unquotedBomItems(List<QuotedLine> bom, BidQuote quote) {
  if (bom.isEmpty) return const [];
  return [
    for (final item in bom)
      if (findQuotedLine(quote.lines, item.name)?.hasPrice != true) item,
  ];
}

/// Shop extras that are not on the builder's estimate list.
List<QuotedLine> extraQuotedLines(List<QuotedLine> bom, BidQuote quote) {
  if (bom.isEmpty) return const [];
  return [
    for (final line in quote.lines)
      if (findQuotedLine(bom, line.name) == null) line,
  ];
}

/// Estimate lines when present; otherwise the union of shop line names.
List<QuotedLine> materialsToCompare(
  List<QuotedLine> bom,
  List<BidQuote> quotes,
) {
  if (bom.isNotEmpty) return List<QuotedLine>.unmodifiable(bom);
  final rows = <QuotedLine>[];
  for (final quote in quotes) {
    for (final line in quote.lines) {
      if (findQuotedLine(rows, line.name) != null) continue;
      rows.add(
        QuotedLine(
          name: line.name,
          quantity: line.quantity,
          unit: line.unit,
          size: line.size,
        ),
      );
    }
  }
  return rows;
}

double quotedLineTotal(QuotedLine bom, QuotedLine quote) {
  if (quote.subtotal > 0) return quote.subtotal;
  final unitPrice = quote.derivedUnitPrice;
  final qty = quote.quantity > 0 ? quote.quantity : bom.quantity;
  if (unitPrice > 0 && qty > 0) return unitPrice * qty;
  return quote.lineTotal;
}

String unitPriceLabel(QuotedLine line, {QuotedLine? bom}) {
  final unitPrice = line.derivedUnitPrice;
  if (unitPrice <= 0) return formatBidMoney(line.lineTotal);
  final unit = line.unit.trim().isNotEmpty
      ? line.unit.trim()
      : (bom?.unit.trim() ?? '');
  if (unit.isEmpty) return formatBidMoney(unitPrice);
  return '${formatBidMoney(unitPrice)} / $unit';
}

String formatBidMoney(double amount) {
  if (amount == amount.roundToDouble()) {
    return '₱${amount.toStringAsFixed(0)}';
  }
  return '₱${amount.toStringAsFixed(2)}';
}

/// One estimate line a shop skipped that another shop did bid.
class MaterialGapFill {
  final String materialName;
  final String missingFromShop;
  final String quotedByShop;
  final double referenceTotal;

  const MaterialGapFill({
    required this.materialName,
    required this.missingFromShop,
    required this.quotedByShop,
    required this.referenceTotal,
  });
}

/// Coverage-aware pick: never treat a skipped line as ₱0, never merge two shops.
class CanvassAdvice {
  final String? suggestedShopId;
  final String headline;
  final String detail;
  final List<MaterialGapFill> gaps;

  const CanvassAdvice({
    this.suggestedShopId,
    required this.headline,
    required this.detail,
    this.gaps = const [],
  });

  bool get hasSuggestion => suggestedShopId != null;
}

/// Prefer the shop that covers more of the estimate; tie-break on lowest all-in.
CanvassAdvice canvassAdvice(List<QuotedLine> bom, List<BidQuote> quotes) {
  if (quotes.isEmpty) {
    return const CanvassAdvice(headline: '', detail: '');
  }

  BidQuote? byCoverageThenPrice(List<BidQuote> list) {
    BidQuote? best;
    for (final quote in list) {
      if (best == null) {
        best = quote;
        continue;
      }
      final cov = bomCoverageCount(bom, quote);
      final bestCov = bomCoverageCount(bom, best);
      if (cov > bestCov) {
        best = quote;
      } else if (cov == bestCov && quote.allInTotal < best.allInTotal) {
        best = quote;
      }
    }
    return best;
  }

  BidQuote cheapest = quotes.first;
  for (final quote in quotes) {
    if (quote.allInTotal < cheapest.allInTotal) cheapest = quote;
  }

  final suggested = byCoverageThenPrice(quotes)!;
  final gaps = <MaterialGapFill>[];
  final seen = <String>{};
  for (final quote in quotes) {
    for (final item in unquotedBomItems(bom, quote)) {
      final filler = lowestPricedShopFor(quotes, item.name);
      if (filler == null || filler.id == quote.id) continue;
      final line = findQuotedLine(filler.lines, item.name);
      if (line == null || !line.hasPrice) continue;
      final key = '${item.name}|${quote.id}|${filler.id}';
      if (!seen.add(key)) continue;
      gaps.add(
        MaterialGapFill(
          materialName: item.name,
          missingFromShop: quote.shopName,
          quotedByShop: filler.shopName,
          referenceTotal: quotedLineTotal(item, line),
        ),
      );
    }
  }

  if (quotes.length == 1) {
    final missing = unquotedBomItems(bom, suggested);
    return CanvassAdvice(
      suggestedShopId: suggested.id,
      headline: '${suggested.shopName} is the only quotation so far.',
      detail: missing.isEmpty
          ? 'Review the line items before you select this shop.'
          : 'They did not price ${missing.map((m) => m.name).join(', ')}. '
              'You can still select them; those items stay unquoted.',
      gaps: gaps,
    );
  }

  final suggestedCov = bomCoverageCount(bom, suggested);
  final total = bom.length;
  final coveredLabel = total > 0 ? '$suggestedCov of $total items' : 'listed items';

  if (suggested.id == cheapest.id) {
    return CanvassAdvice(
      suggestedShopId: suggested.id,
      headline: 'Suggested: ${suggested.shopName}',
      detail: total > 0 && suggestedCov == total
          ? 'Lowest quotation and covers your full estimate list.'
          : 'Best among these bids on coverage and price ($coveredLabel). '
              'Skipped lines are not free — they stay unquoted if you pick this shop.',
      gaps: gaps,
    );
  }

  final skippedByCheap = unquotedBomItems(bom, cheapest)
      .where(
        (item) => findQuotedLine(suggested.lines, item.name)?.hasPrice == true,
      )
      .map((item) => item.name)
      .toList();
  final gapNames = skippedByCheap.isEmpty
      ? 'items on your list'
      : skippedByCheap.join(', ');

  return CanvassAdvice(
    suggestedShopId: suggested.id,
    headline: 'Suggested: ${suggested.shopName}',
    detail:
        '${cheapest.shopName} looks cheaper at ${formatBidMoney(cheapest.allInTotal)}, '
        'but skipped $gapNames. ${suggested.shopName} covers more of the estimate '
        '($coveredLabel) at ${formatBidMoney(suggested.allInTotal)}. '
        'Pick one shop — the other bid does not fill in the gaps.',
    gaps: gaps,
  );
}

class BidQuote {
  final String id;
  final String shopName;
  final double estimatedTotal;
  final double deliveryFee;
  final String leadTimeRaw;
  final int materialsCovered;
  final String message;
  final List<QuotedLine> lines;

  const BidQuote({
    required this.id,
    required this.shopName,
    required this.estimatedTotal,
    required this.deliveryFee,
    required this.leadTimeRaw,
    required this.materialsCovered,
    this.message = '',
    this.lines = const [],
  });

  /// Total the builder is likely comparing: quote + delivery.
  double get allInTotal => estimatedTotal + deliveryFee;

  /// Rough day count parsed from free-text lead times ("3 days", "1 week").
  int? get leadTimeDays => parseLeadTimeDays(leadTimeRaw);

  bool get hasItemPrices => lines.any((line) => line.hasPrice);

  factory BidQuote.fromMap(String id, Map<String, dynamic> data) {
    final lines = parseQuotedLines(data);
    return BidQuote(
      id: id,
      shopName: (data['shopName'] ?? 'Unknown Shop').toString(),
      estimatedTotal: bidAsDouble(
        data['estimatedTotal'] ?? data['totalAmount'] ?? data['amount'],
      ),
      deliveryFee: bidAsDouble(data['deliveryFee']),
      leadTimeRaw: (data['estimatedLeadTime'] ?? '').toString(),
      materialsCovered: lines.isNotEmpty
          ? lines.length
          : _materialsCount(data['availableMaterials']),
      message: (data['message'] ?? '').toString(),
      lines: lines,
    );
  }

  static int _materialsCount(dynamic raw) {
    if (raw is List) return raw.length;
    return 0;
  }

  static int? parseLeadTimeDays(String raw) {
    final text = raw.trim().toLowerCase();
    if (text.isEmpty) return null;

    final number = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(text);
    if (number == null) return null;
    final value = double.tryParse(number.group(1)!);
    if (value == null) return null;

    if (text.contains('week')) return (value * 7).round();
    if (text.contains('month')) return (value * 30).round();
    if (text.contains('hour')) return 1;
    // Default: treat as days.
    return value.round().clamp(1, 365);
  }
}

enum BidHighlight { lowestTotal, fastestLead, mostComplete }

class BidComparison {
  final List<BidQuote> quotes;
  final String? lowestTotalId;
  final String? fastestLeadId;
  final String? mostCompleteId;

  const BidComparison({
    required this.quotes,
    this.lowestTotalId,
    this.fastestLeadId,
    this.mostCompleteId,
  });

  factory BidComparison.fromQuotes(List<BidQuote> quotes) {
    if (quotes.isEmpty) {
      return const BidComparison(quotes: []);
    }

    BidQuote? lowest;
    BidQuote? fastest;
    BidQuote? fullest;

    for (final q in quotes) {
      if (lowest == null || q.allInTotal < lowest.allInTotal) {
        lowest = q;
      } else if (q.allInTotal == lowest.allInTotal &&
          q.materialsCovered > lowest.materialsCovered) {
        lowest = q;
      }

      final days = q.leadTimeDays;
      final bestDays = fastest?.leadTimeDays;
      if (days != null) {
        if (bestDays == null || days < bestDays) {
          fastest = q;
        } else if (days == bestDays && q.allInTotal < (fastest?.allInTotal ?? 0)) {
          fastest = q;
        }
      }

      if (fullest == null || q.materialsCovered > fullest.materialsCovered) {
        fullest = q;
      } else if (q.materialsCovered == fullest.materialsCovered &&
          q.allInTotal < fullest.allInTotal) {
        fullest = q;
      }
    }

    return BidComparison(
      quotes: List.unmodifiable(quotes),
      lowestTotalId: lowest?.id,
      fastestLeadId: fastest?.id,
      mostCompleteId: fullest != null && fullest.materialsCovered > 0
          ? fullest.id
          : null,
    );
  }

  Set<BidHighlight> highlightsFor(String quoteId) {
    final tags = <BidHighlight>{};
    if (quoteId == lowestTotalId) tags.add(BidHighlight.lowestTotal);
    if (quoteId == fastestLeadId) tags.add(BidHighlight.fastestLead);
    if (quoteId == mostCompleteId) tags.add(BidHighlight.mostComplete);
    return tags;
  }

  /// Short plain-English summary for the top of the quotations screen.
  List<String> summaryLines() {
    if (quotes.isEmpty) return const [];
    if (quotes.length == 1) {
      return [
        '${quotes.first.shopName} submitted the only quotation so far '
        '(₱${quotes.first.allInTotal.toStringAsFixed(0)} all-in).',
      ];
    }

    final lines = <String>[
      '${quotes.length} shops quoted. Totals include delivery where provided.',
    ];

    BidQuote? byId(String? id) {
      if (id == null) return null;
      for (final q in quotes) {
        if (q.id == id) return q;
      }
      return null;
    }

    final cheap = byId(lowestTotalId);
    if (cheap != null) {
      lines.add(
        'Lowest all-in: ${cheap.shopName} at ₱${cheap.allInTotal.toStringAsFixed(0)}.',
      );
    }

    final fast = byId(fastestLeadId);
    if (fast != null && fast.leadTimeDays != null) {
      lines.add(
        'Fastest lead time: ${fast.shopName} (~${fast.leadTimeDays} day'
        '${fast.leadTimeDays == 1 ? '' : 's'}).',
      );
    }

    final full = byId(mostCompleteId);
    if (full != null) {
      lines.add(
        'Broadest material cover: ${full.shopName} '
        '(${full.materialsCovered} listed item'
        '${full.materialsCovered == 1 ? '' : 's'}).',
      );
    }

    // Same shop winning multiple tags.
    if (cheap != null &&
        cheap.id == fastestLeadId &&
        cheap.id == mostCompleteId) {
      lines.add(
        '${cheap.shopName} currently leads on price, speed, and coverage — still review line items before accepting.',
      );
    }

    return lines;
  }
}
