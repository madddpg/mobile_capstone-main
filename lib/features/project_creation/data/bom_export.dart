/// Data for a shareable material canvass sheet.
///
/// Builders often canvass over the counter or through chat apps, so the sheet
/// carries the material list only — prices are left blank for the hardware shop
/// to fill in, matching how quotations work inside iConstruct.
library;

class BomExportItem {
  final String name;
  final String category;
  final double quantity;
  final String unit;
  final String? size;
  final String? notes;

  const BomExportItem({
    required this.name,
    required this.category,
    required this.quantity,
    required this.unit,
    this.size,
    this.notes,
  });

  factory BomExportItem.fromMap(Map<String, dynamic> data) {
    final rawQty = data['quantity'];
    final quantity = rawQty is num
        ? rawQty.toDouble()
        : double.tryParse('${rawQty ?? 0}') ?? 0;

    return BomExportItem(
      name: (data['name'] ?? '').toString().trim(),
      category: (data['category'] ?? '').toString().trim().isEmpty
          ? 'Materials'
          : (data['category']).toString().trim(),
      quantity: quantity,
      unit: (data['unit'] ?? '').toString().trim(),
      size: _cleaned(data['size']),
      notes: _cleaned(data['notes']),
    );
  }

  static String? _cleaned(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty || text == 'null' ? null : text;
  }

  /// Quantity without a trailing `.0`, or a dash when it was never set.
  String get quantityLabel {
    if (quantity <= 0) return '—';
    if (quantity == quantity.roundToDouble()) {
      return quantity.toStringAsFixed(0);
    }
    return quantity.toStringAsFixed(2);
  }
}

class BomExportData {
  final String estimateName;
  final String renovationType;
  final double areaSqm;
  final String? budgetPreference;
  final String? notes;
  final List<BomExportItem> materials;
  final DateTime generatedAt;

  BomExportData({
    required this.estimateName,
    required this.renovationType,
    required this.areaSqm,
    required this.materials,
    this.budgetPreference,
    this.notes,
    DateTime? generatedAt,
  }) : generatedAt = generatedAt ?? DateTime.now();

  /// Builds from the material maps stored on a saved estimate or project post.
  ///
  /// Accepts legacy entries that were saved as plain strings.
  factory BomExportData.fromMaterials({
    required String estimateName,
    required String renovationType,
    required double areaSqm,
    required List<dynamic> materials,
    String? budgetPreference,
    String? notes,
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
      budgetPreference: budgetPreference,
      notes: notes,
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
