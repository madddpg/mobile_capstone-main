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
  List<Map<String, dynamic>> excludedWork = const [],
  String coverage = '',
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
