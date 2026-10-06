/// The fields a posted estimate carries for the shop dashboard.
///
/// The dashboard is a separate app maintained by another developer, and it
/// reads a fixed set of fields off `projectPosts/{postId}`. `ownerName` was
/// never written, so every post reached shops with no name on it. Assembling
/// the contract in one place, away from the screen, is what makes it testable.
library;

/// The quantity a hardware shop should be asked for on one material line.
///
/// The text the builder typed is the quantity, including after they clear a
/// line to 0 and type a new number. A stored 0 must not win over that later
/// number. An explicit 0, or text that is not a number, stays 0 so the post
/// can be refused. When there is no text field (a saved line being read back),
/// the stored number is used.
double postedLineQuantity({
  required double stored,
  String? typedText,
}) {
  if (typedText != null) {
    final typed = double.tryParse(typedText.trim());
    if (typed != null && typed.isFinite && typed > 0) return typed;
    return 0;
  }
  if (stored.isFinite && stored > 0) return stored;
  return 0;
}

double _asDouble(dynamic raw) {
  if (raw is num) return raw.toDouble();
  return double.tryParse('${raw ?? ''}'.trim()) ?? 0;
}

/// One material line as it was saved on an estimate.
class SavedMaterialLine {
  final String name;
  final double quantity;
  final String unit;
  final String? size;
  final String category;

  const SavedMaterialLine({
    required this.name,
    required this.quantity,
    required this.unit,
    this.size,
    this.category = 'Material',
  });
}

/// Structured rows from a saved estimate. Plain-string leftovers are not
/// included; those never had a quantity.
List<SavedMaterialLine> savedMaterialLines(List<dynamic> raw) {
  final lines = <SavedMaterialLine>[];
  for (final item in raw) {
    if (item is! Map) continue;
    final map = Map<String, dynamic>.from(item);
    final name = (map['name'] ?? '').toString().trim();
    if (name.isEmpty) continue;
    final sizeText = map['size']?.toString().trim() ?? '';
    final category = (map['category'] ?? '').toString().trim();
    lines.add(
      SavedMaterialLine(
        name: name,
        quantity: postedLineQuantity(stored: _asDouble(map['quantity'])),
        unit: (map['unit'] ?? '').toString().trim(),
        size: sizeText.isEmpty || sizeText == 'null' ? null : sizeText,
        category: category.isEmpty ? 'Material' : category,
      ),
    );
  }
  return lines;
}

/// Names saved before lines carried a quantity.
List<String> legacyMaterialNames(List<dynamic> raw) {
  final names = <String>[];
  for (final item in raw) {
    if (item is Map) continue;
    final name = item.toString().trim();
    if (name.isNotEmpty) names.add(name);
  }
  return names;
}

/// The builder's name as a shop sees it in chat and on the board.
///
/// Falls back to the part of the email before the @ rather than to "Unknown":
/// a shop replying to a person wants something to call them.
String ownerDisplayName({
  String? firstName,
  String? lastName,
  String? email,
}) {
  final full = [
    (firstName ?? '').trim(),
    (lastName ?? '').trim(),
  ].where((part) => part.isNotEmpty).join(' ');
  if (full.isNotEmpty) return full;

  final address = (email ?? '').trim();
  final at = address.indexOf('@');
  if (at > 0) return address.substring(0, at);
  return 'Builder';
}

/// The fields every posted estimate carries, without the server timestamps and
/// lifecycle fields the caller adds.
///
/// Empty optional fields are left out rather than written as empty strings, so
/// a missing value reads as missing rather than as a blank the dashboard has
/// to special-case.
Map<String, dynamic> projectPostFields({
  required String postId,
  required String userId,
  required String projectId,
  required String projectName,
  required String projectType,
  required String projectScope,
  required String ownerName,
  required List<Map<String, dynamic>> materials,
  required double totalAreaSqm,
  required String budget,
  Map<String, dynamic>? siteDetails,
  String remarks = '',
  List<Map<String, dynamic>> excludedWork = const [],
  String coverage = '',
  List<String> renovationTypes = const [],
}) {
  return {
    'postId': postId,
    'userId': userId,
    // The rules treat userId as the owner; builderId is kept for records and
    // dashboards written against the older spelling.
    'builderId': userId,
    'projectId': projectId,
    'projectName': projectName.trim(),
    'projectType': projectType.trim(),
    // The renovation type: Cosmetic, Structural or Functional. The dashboard
    // reads it under that meaning, and the app parses the words "Full
    // Renovation" and "Extension" here as types, so how much of the space the
    // job covers is a separate field and never written into this one.
    'projectScope': projectScope,
    // Every kind of work chosen. projectScope stays a single label — the
    // heaviest of them — because the dashboard reads it as one; this carries
    // the full selection next to it rather than changing what it holds.
    if (renovationTypes.isNotEmpty) 'renovationTypes': renovationTypes,
    if (coverage.trim().isNotEmpty) 'coverage': coverage.trim(),
    'ownerName': ownerName.trim(),
    'materials': materials,
    'materialsCount': materials.length,
    'totalAreaSqm': totalAreaSqm,
    'budget': budget,
    if (siteDetails != null) 'siteDetails': siteDetails,
    if (remarks.trim().isNotEmpty) 'remarks': remarks.trim(),
    // Work the builder was offered and turned down. Left out entirely when
    // there is none, so "nothing excluded" reads as absent rather than as an
    // empty list the dashboard has to special-case.
    if (excludedWork.isNotEmpty) 'excludedWork': excludedWork,
  };
}
