/// Data for a shareable material canvass sheet.
///
/// Builders often canvass over the counter or through chat apps, so the sheet
/// carries the material list only — prices are left blank for the hardware shop
/// to fill in, matching how quotations work inside iConstruct.
library;

import 'package:iconstruct/features/bidding/data/bid_comparison.dart';
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
  });

  factory BomExportItem.fromMap(Map<String, dynamic> data) {
    final rawQty = data['quantity'] ?? data['qty'];
    final quantity = rawQty is num
        ? rawQty.toDouble()
        : double.tryParse('${rawQty ?? 0}') ?? 0;

    final rawPrice = data['unitPrice'] ?? data['price'];
    final unitPrice = rawPrice is num
        ? rawPrice.toDouble()
        : double.tryParse('${rawPrice ?? 0}'.replaceAll(',', '')) ?? 0.0;

    final rawAmount = data['subtotal'] ?? data['amount'] ?? data['lineTotal'] ?? data['total'];
    var amount = rawAmount is num
        ? rawAmount.toDouble()
        : double.tryParse('${rawAmount ?? 0}'.replaceAll(',', '')) ?? 0.0;
    if (amount <= 0 && unitPrice > 0 && quantity > 0) {
      amount = unitPrice * quantity;
    }

    final rawStatus = '${data['status'] ?? ''}'.trim().toLowerCase();
    final isSub = rawStatus == 'substituted' ||
        rawStatus == 'substitute' ||
        data['isSubstitute'] == true ||
        ('${data['requestedName'] ?? ''}'.trim().isNotEmpty &&
            '${data['requestedName'] ?? ''}'.trim().toLowerCase() !=
                (data['name'] ?? '').toString().trim().toLowerCase());

    final isUnavail = rawStatus == 'unavailable' ||
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

  /// Total sum of all priced items on this sheet.
  double get totalAmount {
    return materials.fold<double>(0.0, (sum, item) {
      if (!item.isUnavailable && item.amount > 0) {
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

  /// Builds from the project BOM materials reconciled with the accepted quotation.
  ///
  /// For items the shop substituted, displays the substitute product name with
  /// substitute badge and note "instead of `<original item>`".
  /// For items marked unavailable, displays them with the UNAVAILABLE badge,
  /// Unit Price as 'Unavailable', and Amount as '—'.
  /// For quoted items, displays their updated unit price and line total amount.
  factory BomExportData.fromQuotation({
    required String estimateName,
    required String renovationType,
    required double areaSqm,
    required List<dynamic> materials,
    required List<Map<String, dynamic>> quotationItems,
    String? supplierName,
    List<ExcludedWork> excluded = const [],
    String? budgetPreference,
    String? notes,
    DateTime? generatedAt,
  }) {
    final quotedLines = parseQuotedLines({'materials': quotationItems});
    final matchedIndices = <int>{};
    final items = <BomExportItem>[];

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
      final category = (bomMap['category'] ?? '').toString().trim().isEmpty
          ? 'Materials'
          : bomMap['category'].toString().trim();
      final rawQty = bomMap['quantity'] ?? bomMap['qty'];
      final quantity = rawQty is num
          ? rawQty.toDouble()
          : double.tryParse('${rawQty ?? 0}') ?? 0;
      final unit = (bomMap['unit'] ?? '').toString().trim();
      final size = BomExportItem._cleaned(bomMap['size']);
      final bomNotes = BomExportItem._cleaned(bomMap['notes'] ?? bomMap['note']);

      // Look for a matching quoted line from the supplier
      QuotedLine? matchedLine;
      for (var i = 0; i < quotedLines.length; i++) {
        if (matchedIndices.contains(i)) continue;
        final q = quotedLines[i];
        final matchTarget = q.matchName;
        if (normalizeMaterialName(matchTarget) == normalizeMaterialName(bomName) ||
            (matchTarget.isNotEmpty &&
                bomName.isNotEmpty &&
                (normalizeMaterialName(matchTarget).contains(normalizeMaterialName(bomName)) ||
                    normalizeMaterialName(bomName).contains(normalizeMaterialName(matchTarget))))) {
          matchedLine = q;
          matchedIndices.add(i);
          break;
        }
      }

      if (matchedLine == null) {
        // Not quoted by the shop or shop didn't supply it
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
      } else if (matchedLine.markedUnavailable || !matchedLine.hasPrice) {
        // Quoted line was marked unavailable
        items.add(
          BomExportItem(
            name: matchedLine.name.isNotEmpty ? matchedLine.name : bomName,
            category: category,
            quantity: quantity,
            unit: unit,
            size: size ?? (matchedLine.size.isNotEmpty ? matchedLine.size : null),
            notes: matchedLine.note.isNotEmpty ? matchedLine.note : bomNotes,
            unitPrice: 0.0,
            amount: 0.0,
            isSubstitute: matchedLine.isSubstitute,
            requestedName: matchedLine.isSubstitute ? bomName : null,
            isUnavailable: true,
          ),
        );
      } else {
        // Quoted line has price / substitute
        final unitPrice = matchedLine.derivedUnitPrice;
        final amount = matchedLine.lineTotal;
        items.add(
          BomExportItem(
            name: matchedLine.name.isNotEmpty ? matchedLine.name : bomName,
            category: category,
            quantity: matchedLine.quantity > 0 ? matchedLine.quantity : quantity,
            unit: matchedLine.unit.isNotEmpty ? matchedLine.unit : unit,
            size: matchedLine.size.isNotEmpty ? matchedLine.size : size,
            notes: matchedLine.note.isNotEmpty ? matchedLine.note : bomNotes,
            unitPrice: unitPrice,
            amount: amount,
            isSubstitute: matchedLine.isSubstitute,
            requestedName: matchedLine.isSubstitute ? bomName : null,
            isUnavailable: false,
          ),
        );
      }
    }

    // Also include any extra items the shop quoted that weren't matched in BOM
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
          requestedName: extra.requestedName.isNotEmpty ? extra.requestedName : null,
          isUnavailable: extra.markedUnavailable || !extra.hasPrice,
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
    final date = '${generatedAt.year}'
        '${generatedAt.month.toString().padLeft(2, '0')}'
        '${generatedAt.day.toString().padLeft(2, '0')}';
    return '${slug.isEmpty ? 'material-estimate' : slug}-bom-$date';
  }
}
