import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:iconstruct/core/firebase/firestore_coerce.dart';
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

  final String projectScope; // Full Renovation, Extension

  RenovationScope get scope => RenovationScope.fromString(projectScope);

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
    this.projectScope = 'Full Renovation',
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
      projectScope: asString(data['projectScope'], fallback: 'Full Renovation'),
    );
  }
}
