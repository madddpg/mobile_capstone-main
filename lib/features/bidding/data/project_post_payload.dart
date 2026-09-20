/// The fields a posted estimate carries for the shop dashboard.
///
/// The dashboard is a separate app maintained by another developer, and it
/// reads a fixed set of fields off `projectPosts/{postId}`. `ownerName` was
/// never written, so every post reached shops with no name on it. Assembling
/// the contract in one place, away from the screen, is what makes it testable.
library;

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
    'projectScope': projectScope,
    'ownerName': ownerName.trim(),
    'materials': materials,
    'materialsCount': materials.length,
    'totalAreaSqm': totalAreaSqm,
    'budget': budget,
    if (siteDetails != null) 'siteDetails': siteDetails,
    if (remarks.trim().isNotEmpty) 'remarks': remarks.trim(),
  };
}
