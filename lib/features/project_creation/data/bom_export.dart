/// Data for a shareable material canvass sheet.
///
/// Builders often canvass over the counter or through chat apps, so the sheet
/// carries the material list only — prices are left blank for the hardware shop
/// to fill in, matching how quotations work inside iConstruct.
library;

import 'package:iconstruct/features/bidding/data/bid_comparison.dart';
import 'package:iconstruct/features/bidding/data/partial_acceptance.dart';
import 'package:iconstruct/features/project_creation/data/excluded_work.dart';
import 'package:iconstruct/features/project_creation/data/ph_renovation_rates.dart';

class BomExportItem {
  final String name;
  final String category;
  final double quantity;
  final String unit;
  final String? size;
  final String? notes;
  final double unitPrice;
  final double amount;
  final bool isSubstitute;
  final String? requestedName;
  final bool isUnavailable;

  /// Why the builder left this line out of a partly accepted quotation, such
  /// as "Overpriced". Null on a line that is part of the order.
  final String? declineReason;

  const BomExportItem({
    required this.name,
    required this.category,
    required this.quantity,
    required this.unit,
    this.size,
    this.notes,
    this.unitPrice = 0.0,
    this.amount = 0.0,
    this.isSubstitute = false,
    this.requestedName,
    this.isUnavailable = false,
    this.declineReason,
  });

  /// The builder did not order this line from the selected shop.
  bool get isDeclined => declineReason != null;

  factory BomExportItem.fromMap(Map<String, dynamic> data) {
    final rawQty = data['quantity'] ?? data['qty'];
    final quantity = rawQty is num
        ? rawQty.toDouble()
        : double.tryParse('${rawQty ?? 0}') ?? 0;

    final rawPrice = data['unitPrice'] ?? data['price'];
    final unitPrice = rawPrice is num
        ? rawPrice.toDouble()
        : double.tryParse('${rawPrice ?? 0}'.replaceAll(',', '')) ?? 0.0;

    final rawAmount =
        data['subtotal'] ??
        data['amount'] ??
        data['lineTotal'] ??
        data['total'];
    var amount = rawAmount is num
        ? rawAmount.toDouble()
        : double.tryParse('${rawAmount ?? 0}'.replaceAll(',', '')) ?? 0.0;
    if (amount <= 0 && unitPrice > 0 && quantity > 0) {
      amount = unitPrice * quantity;
    }

    final rawStatus = '${data['status'] ?? ''}'.trim().toLowerCase();
    final isSub =
        rawStatus == 'substituted' ||
        rawStatus == 'substitute' ||
        data['isSubstitute'] == true ||
        ('${data['requestedName'] ?? ''}'.trim().isNotEmpty &&
            '${data['requestedName'] ?? ''}'.trim().toLowerCase() !=
                (data['name'] ?? '').toString().trim().toLowerCase());

    final isUnavail =
        rawStatus == 'unavailable' ||
        rawStatus == 'notavailable' ||
        rawStatus == 'outofstock' ||
        data['available'] == false ||
        data['markedUnavailable'] == true ||
        data['isUnavailable'] == true;

    return BomExportItem(
      name: (data['name'] ?? '').toString().trim(),
      category: (data['category'] ?? '').toString().trim().isEmpty
          ? 'Materials'
          : (data['category']).toString().trim(),
      quantity: quantity,
      unit: (data['unit'] ?? '').toString().trim(),
      size: _cleaned(data['size']),
      notes: _cleaned(data['notes'] ?? data['note']),
      unitPrice: unitPrice,
      amount: isUnavail ? 0.0 : amount,
      isSubstitute: isSub,
      requestedName: _cleaned(data['requestedName']),
      isUnavailable: isUnavail,
    );
  }

  static String? _cleaned(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty || text == 'null' ? null : text;
  }

  /// The quantity exactly, without a trailing `.0`, or a dash when it was
  /// never set.
  String get quantityLabel {
    if (quantity <= 0) return '—';
    return PhRenovationRates.qtyText(quantity);
  }

  bool get hasPrice => !isUnavailable && (unitPrice > 0 || amount > 0);
}

class BomExportData {
  final String estimateName;
  final String renovationType;
  final double areaSqm;
  final String? budgetPreference;
  final String? notes;
  final List<BomExportItem> materials;

  /// Work the builder deliberately left out. Printed on the sheet so a shop
  /// quotes the list above it and knows the rest was a decision, not an
  /// omission.
  final List<ExcludedWork> excluded;

  final DateTime generatedAt;

  /// If a supplier was selected (e.g., status is "supplier picked"), records
  /// the shop name and whether prices are populated.
  final String? supplierName;
  final bool isSupplierPicked;

  BomExportData({
    required this.estimateName,
    required this.renovationType,
    required this.areaSqm,
    required this.materials,
    this.excluded = const [],
    this.budgetPreference,
    this.notes,
    this.supplierName,
    this.isSupplierPicked = false,
    DateTime? generatedAt,
  }) : generatedAt = generatedAt ?? DateTime.now();

  /// Total of the priced lines on this sheet that are part of the order.
  /// Unavailable lines and lines the builder declined are left out, so a
  /// partly accepted quotation totals what was actually ordered.
  double get totalAmount {
    return materials.fold<double>(0.0, (sum, item) {
      if (!item.isUnavailable && !item.isDeclined && item.amount > 0) {
        return sum + item.amount;
      }
      return sum;
    });
  }

  /// Builds from the material maps stored on a saved estimate or project post.
  ///
  /// Accepts legacy entries that were saved as plain strings.
  factory BomExportData.fromMaterials({
    required String estimateName,
    required String renovationType,
    required double areaSqm,
    required List<dynamic> materials,
    List<ExcludedWork> excluded = const [],
    String? budgetPreference,
    String? notes,
    String? supplierName,
    bool isSupplierPicked = false,
    DateTime? generatedAt,
  }) {
    final items = <BomExportItem>[];
    for (final raw in materials) {
      if (raw is Map) {
        final item = BomExportItem.fromMap(Map<String, dynamic>.from(raw));
        if (item.name.isNotEmpty) items.add(item);
      } else {
        final name = raw.toString().trim();
        if (name.isNotEmpty) {
          items.add(
            BomExportItem(
              name: name,
              category: 'Materials',
              quantity: 0,
              unit: '',
            ),
          );
        }
      }
    }

    return BomExportData(
      estimateName: estimateName.trim().isEmpty
          ? 'Material Estimate'
          : estimateName.trim(),
      renovationType: renovationType.replaceAll('\n', ' ').trim(),
      areaSqm: areaSqm,
      materials: items,
      excluded: excluded,
      budgetPreference: budgetPreference,
      notes: notes,
      supplierName: supplierName,
      isSupplierPicked: isSupplierPicked,
      generatedAt: generatedAt,
    );
  }

  /// Builds the sheet for an estimate whose supplier was picked: the posted
  /// material list, reconciled line by line with the selected shop's
  /// quotation.
  ///
  /// A line the shop substituted shows the shop's product with a SUBSTITUTE
  /// badge and "instead of" and the material asked for. A line the shop cannot
  /// supply shows UNAVAILABLE and no amount. Every other quoted line shows the
  /// shop's unit price and amount; after an accepted counter-offer that is the
  /// agreed price, since accepting one rewrites the line's prices.
  ///
  /// On a partly accepted quotation ([quotationStatus] `partially_accepted`)
  /// the lines the builder left out show as not ordered, with the reason they
  /// gave, and are not counted in the total.
  factory BomExportData.fromQuotation({
    required String estimateName,
    required String renovationType,
    required double areaSqm,
    required List<dynamic> materials,
    required List<Map<String, dynamic>> quotationItems,
    String quotationStatus = '',
    String? supplierName,
    List<ExcludedWork> excluded = const [],
    String? budgetPreference,
    String? notes,
    DateTime? generatedAt,
  }) {
    final quotedLines = parseQuotedLines({'materials': quotationItems});
    final declined = _declinedLines(quotationItems, quotationStatus);
    final matchedIndices = <int>{};
    final items = <BomExportItem>[];

    String? declineFor(QuotedLine line) =>
        declined[normalizeMaterialName(line.matchName)];

    for (final raw in materials) {
      if (raw is! Map) {
        final name = raw.toString().trim();
        if (name.isNotEmpty) {
          items.add(
            BomExportItem(
              name: name,
              category: 'Materials',
              quantity: 0,
              unit: '',
            ),
          );
        }
        continue;
      }

      final bomMap = Map<String, dynamic>.from(raw);
      final bomName = (bomMap['name'] ?? '').toString().trim();
      if (bomName.isEmpty) continue;
      final category = (bomMap['category'] ?? '').toString().trim().isEmpty
          ? 'Materials'
          : bomMap['category'].toString().trim();
      final rawQty = bomMap['quantity'] ?? bomMap['qty'];
      final quantity = rawQty is num
          ? rawQty.toDouble()
          : double.tryParse('${rawQty ?? 0}') ?? 0;
      final unit = (bomMap['unit'] ?? '').toString().trim();
      final size = BomExportItem._cleaned(bomMap['size']);
      final bomNotes = BomExportItem._cleaned(
        bomMap['notes'] ?? bomMap['note'],
      );

      final index = _matchQuotedLine(quotedLines, bomName, matchedIndices);
      final matchedLine = index == null ? null : quotedLines[index];
      if (index != null) matchedIndices.add(index);

      if (matchedLine == null) {
        // The shop did not quote this line.
        items.add(
          BomExportItem(
            name: bomName,
            category: category,
            quantity: quantity,
            unit: unit,
            size: size,
            notes: bomNotes,
          ),
        );
      } else if (!matchedLine.hasPrice) {
        // Marked unavailable, or left without a price: either way the shop
        // is not supplying it.
        items.add(
          BomExportItem(
            name: matchedLine.name.isNotEmpty ? matchedLine.name : bomName,
            category: category,
            quantity: quantity,
            unit: unit,
            size:
                size ?? (matchedLine.size.isNotEmpty ? matchedLine.size : null),
            notes: matchedLine.note.isNotEmpty ? matchedLine.note : bomNotes,
            isSubstitute: matchedLine.isSubstitute,
            requestedName: matchedLine.isSubstitute ? bomName : null,
            isUnavailable: true,
          ),
        );
      } else {
        items.add(
          BomExportItem(
            name: matchedLine.name.isNotEmpty ? matchedLine.name : bomName,
            category: category,
            quantity: matchedLine.quantity > 0
                ? matchedLine.quantity
                : quantity,
            unit: matchedLine.unit.isNotEmpty ? matchedLine.unit : unit,
            size: matchedLine.size.isNotEmpty ? matchedLine.size : size,
            notes: matchedLine.note.isNotEmpty ? matchedLine.note : bomNotes,
            unitPrice: matchedLine.derivedUnitPrice,
            amount: matchedLine.lineTotal,
            isSubstitute: matchedLine.isSubstitute,
            requestedName: matchedLine.isSubstitute ? bomName : null,
            declineReason: declineFor(matchedLine),
          ),
        );
      }
    }

    // Lines the shop quoted that match nothing on the estimate.
    for (var i = 0; i < quotedLines.length; i++) {
      if (matchedIndices.contains(i)) continue;
      final extra = quotedLines[i];
      if (extra.name.isEmpty) continue;
      items.add(
        BomExportItem(
          name: extra.name,
          category: 'Extra Items Quoted',
          quantity: extra.quantity,
          unit: extra.unit,
          size: extra.size.isNotEmpty ? extra.size : null,
          notes: extra.note.isNotEmpty ? extra.note : null,
          unitPrice: extra.derivedUnitPrice,
          amount: extra.lineTotal,
          isSubstitute: extra.isSubstitute,
          requestedName: extra.requestedName.isNotEmpty
              ? extra.requestedName
              : null,
          isUnavailable: !extra.hasPrice,
          declineReason: extra.hasPrice ? declineFor(extra) : null,
        ),
      );
    }

    return BomExportData(
      estimateName: estimateName.trim().isEmpty
          ? 'Material Estimate'
          : estimateName.trim(),
      renovationType: renovationType.replaceAll('\n', ' ').trim(),
      areaSqm: areaSqm,
      materials: items,
      excluded: excluded,
      budgetPreference: budgetPreference,
      notes: notes,
      supplierName: supplierName,
      isSupplierPicked: true,
      generatedAt: generatedAt,
    );
  }

  /// The quoted line for the estimate material [bomName], skipping lines
  /// already used. An exact name wins over a partial one, so "Portland
  /// Cement - Slab" is never paired with the screed cement line just because
  /// it was listed first.
  static int? _matchQuotedLine(
    List<QuotedLine> lines,
    String bomName,
    Set<int> used,
  ) {
    final target = normalizeMaterialName(bomName);
    if (target.isEmpty) return null;
    for (var i = 0; i < lines.length; i++) {
      if (used.contains(i)) continue;
      if (normalizeMaterialName(lines[i].matchName) == target) return i;
    }
    for (var i = 0; i < lines.length; i++) {
      if (used.contains(i)) continue;
      final name = normalizeMaterialName(lines[i].matchName);
      if (name.isEmpty) continue;
      if (name.contains(target) || target.contains(name)) return i;
    }
    return null;
  }

  /// The lines the builder left out of a partly accepted quotation, by
  /// normalized material name, with the reason shown for each.
  ///
  /// The per-line `accepted` flags only mean something on a quotation marked
  /// partially accepted; on any other they are ignored, as in
  /// `readAcceptance`.
  static Map<String, String> _declinedLines(
    List<Map<String, dynamic>> quotationItems,
    String quotationStatus,
  ) {
    final partial =
        quotationStatus.trim().toLowerCase() ==
        AcceptanceOutcome.statusPartiallyAccepted;
    if (!partial) return const {};
    return {
      for (final item in quotationItems)
        if (item['accepted'] == false)
          normalizeMaterialName(
            isSubstitutedLine(item)
                ? requestedItemName(item)
                : (item['name'] ?? '').toString(),
          ): declineReasonOf(item)?.label ?? 'Not ordered',
    };
  }

  /// Materials grouped by category, in first-seen order.
  Map<String, List<BomExportItem>> get byCategory {
    final grouped = <String, List<BomExportItem>>{};
    for (final item in materials) {
      grouped.putIfAbsent(item.category, () => []).add(item);
    }
    return grouped;
  }

  /// Safe base name for the exported file.
  String get fileBaseName {
    final slug = estimateName
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    final date =
        '${generatedAt.year}'
        '${generatedAt.month.toString().padLeft(2, '0')}'
        '${generatedAt.day.toString().padLeft(2, '0')}';
    return '${slug.isEmpty ? 'material-estimate' : slug}-bom-$date';
  }
}
