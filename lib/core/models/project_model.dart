import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:iconstruct/core/firebase/firestore_coerce.dart';
import 'package:iconstruct/features/project_creation/data/excluded_work.dart';
import 'package:iconstruct/features/project_creation/data/renovation_coverage.dart';
import 'package:iconstruct/features/project_creation/data/renovation_scope.dart';

/// Saved material-estimate document for the planning / canvassing cycle.
class ProjectModel {
  final String id;
  final String projectName;
  final String projectType;
  final int materialCount;
  final double projectArea;
  final String costLevel; // Low, Medium, High
  final List<dynamic> materials;
  final String status; // Draft, Ready, Posted
  final DateTime lastUpdated;
  final String? postId;

  final String projectScope; // Cosmetic, Structural, Functional

  /// Whether the estimate carries room measurements. The area then comes from
  /// the takeoff and is not the builder's to retype.
  final bool hasSiteDetails;

  /// Work the builder was offered and left out. Reopened with the estimate and
  /// printed on the canvass sheet, so a decision made once is not lost.
  final List<ExcludedWork> excludedWork;

  /// How much of the space the job covers. Its own field: `projectScope` holds
  /// the renovation type, and the words "Full Renovation" and "Extension" are
  /// already read as types there.
  final RenovationCoverage coverage;

  RenovationScope get scope => RenovationScope.fromString(projectScope);

  /// Every kind of work the estimate covers. Older estimates hold only
  /// [projectScope], which reads as that one kind.
  final List<String> renovationTypeNames;

  RenovationTypes get types =>
      RenovationTypes.fromStored(renovationTypeNames, projectScope);

  ProjectModel({
    required this.id,
    required this.projectName,
    required this.projectType,
    required this.materialCount,
    required this.projectArea,
    required this.costLevel,
    required this.materials,
    required this.status,
    required this.lastUpdated,
    this.postId,
    this.projectScope = 'Cosmetic',
    this.hasSiteDetails = false,
    this.excludedWork = const [],
    this.coverage = RenovationCoverage.full,
    this.renovationTypeNames = const [],
  });

  factory ProjectModel.fromDocument(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? const {};
    return ProjectModel.fromMap(doc.id, data);
  }

  /// Coercion-safe parse. Every field tolerates the wrong scalar type / a
  /// missing key / a web-written alias without throwing.
  factory ProjectModel.fromMap(String id, Map<String, dynamic> data) {
    return ProjectModel(
      id: id,
      projectName: asString(firstOf(data, ['projectName', 'name']),
          fallback: 'Unknown Project'),
      projectType: asString(firstOf(data, ['projectType', 'renovationType'])),
      materialCount: asInt(firstOf(data, ['materialsCount', 'materialCount'])),
      projectArea: asDouble(firstOf(data, ['totalAreaSqm', 'projectArea', 'areaSqm'])),
      costLevel: asString(firstOf(data, ['costLevel', 'budget']),
          fallback: 'Unknown'),
      // Materials may be stored as a list of strings (legacy) or as a list of
      // structured maps containing name/quantity/unit, etc.
      materials: asList(firstOf(
          data, ['materials', 'selectedMaterials', 'availableMaterials'])),
      status: asString(data['status'], fallback: 'Draft'),
      lastUpdated: asDate(firstOf(data, ['updatedAt', 'lastUpdated'])) ??
          DateTime.now(),
      postId: asStringOrNull(data['postId']),
      projectScope: asString(data['projectScope'], fallback: 'Cosmetic'),
      hasSiteDetails: data['siteDetails'] is Map,
      excludedWork: ExcludedWork.listFrom(data['excludedWork']),
      coverage: RenovationCoverage.fromString(asStringOrNull(data['coverage'])),
      renovationTypeNames: [
        for (final name in asList(data['renovationTypes'])) '$name',
      ],
    );
  }
}
