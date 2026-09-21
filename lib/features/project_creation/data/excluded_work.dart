/// Work the builder was offered and deliberately left out.
///
/// A material removed from the bill of materials used to simply vanish. The
/// shop then received a list with no way to tell work that was deliberately
/// excluded from work that was forgotten, and quoted — or did not quote — on a
/// guess. Carrying the removed lines alongside the kept ones says plainly what
/// is not being asked for, so a quotation covers the included work and nothing
/// else.
library;

/// One line the builder took out of the estimate.
///
/// Holds what a reader needs to recognise the material, including the quantity
/// it would have carried: "no floor tiles" and "no 96 pieces of floor tile"
/// tell a shop different things about the size of what was dropped.
class ExcludedWork {
  final String name;
  final String category;
  final String unit;
  final String? size;

  /// What the line would have been, had it stayed. Zero when it never had one.
  final double quantity;

  const ExcludedWork({
    required this.name,
    this.category = '',
    this.unit = '',
    this.size,
    this.quantity = 0,
  });

  /// Quantity without a trailing `.0`, or a dash when it never had one.
  String get quantityLabel {
    if (quantity <= 0) return '—';
    if (quantity == quantity.roundToDouble()) return quantity.toStringAsFixed(0);
    return quantity.toStringAsFixed(2);
  }

  /// The line as one phrase: "Floor Tile 600x600 — 96 pcs".
  String get label {
    final parts = <String>[name];
    if ((size ?? '').trim().isNotEmpty) parts.add(size!.trim());
    final head = parts.join(' ');
    if (quantity <= 0) return head;
    return '$head — $quantityLabel${unit.trim().isEmpty ? '' : ' ${unit.trim()}'}';
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        if (category.trim().isNotEmpty) 'category': category.trim(),
        if (unit.trim().isNotEmpty) 'unit': unit.trim(),
        if ((size ?? '').trim().isNotEmpty) 'size': size!.trim(),
        if (quantity > 0) 'quantity': quantity,
      };

  static ExcludedWork? fromMap(Map<String, dynamic>? map) {
    if (map == null) return null;
    final name = (map['name'] ?? '').toString().trim();
    if (name.isEmpty) return null;
    final rawQty = map['quantity'];
    return ExcludedWork(
      name: name,
      category: (map['category'] ?? '').toString().trim(),
      unit: (map['unit'] ?? '').toString().trim(),
      size: _cleaned(map['size']),
      quantity: rawQty is num
          ? rawQty.toDouble()
          : double.tryParse('${rawQty ?? ''}') ?? 0,
    );
  }

  /// Reads a saved list, skipping anything that is not a usable entry.
  ///
  /// Accepts plain strings, which is how a list written by another client or
  /// an older version of the app may arrive.
  static List<ExcludedWork> listFrom(Object? raw) {
    if (raw is! List) return const [];
    final items = <ExcludedWork>[];
    for (final entry in raw) {
      if (entry is Map) {
        final item = fromMap(Map<String, dynamic>.from(entry));
        if (item != null) items.add(item);
      } else {
        final name = entry?.toString().trim() ?? '';
        if (name.isNotEmpty) items.add(ExcludedWork(name: name));
      }
    }
    return items;
  }

  static List<Map<String, dynamic>> listToMaps(List<ExcludedWork> items) =>
      [for (final item in items) item.toMap()];

  static String? _cleaned(Object? value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty || text == 'null' ? null : text;
  }

  @override
  String toString() => 'ExcludedWork($label)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ExcludedWork &&
          name == other.name &&
          category == other.category &&
          unit == other.unit &&
          size == other.size &&
          quantity == other.quantity);

  @override
  int get hashCode => Object.hash(name, category, unit, size, quantity);
}
