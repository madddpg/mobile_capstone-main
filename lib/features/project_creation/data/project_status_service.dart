import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:iconstruct/features/project_creation/data/project_lifecycle.dart';

/// Keeps a saved estimate's planning status in step with its bidding post.
///
/// Cloud Functions do the same reconciliation server-side; this client path
/// keeps tracking accurate for builders even when the trigger has not run.
class ProjectStatusService {
  final FirebaseFirestore _firestore;

  ProjectStatusService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  static final ProjectStatusService instance = ProjectStatusService();

  /// Guards against repeat writes while a stream rebuilds.
  final Set<String> _applied = <String>{};

  DocumentReference<Map<String, dynamic>> _savedProjectRef(
    String userId,
    String projectId,
  ) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('saved_projects')
        .doc(projectId);
  }

  /// Advances [projectId] when bids arrive or an offer is accepted.
  ///
  /// Never moves a project backwards, and never overrides a cycle the builder
  /// already marked complete.
  Future<void> syncFromPost({
    required String userId,
    required String projectId,
    required String storedStatus,
    required Map<String, dynamic>? post,
  }) async {
    final current = ProjectLifecycle.stageIndex(storedStatus);
    if (current >= ProjectLifecycle.stageCompleted) return;

    final derived = ProjectLifecycle.stageFromPost(post);
    if (derived <= current) return;

    final guard = '$userId/$projectId:$derived';
    if (!_applied.add(guard)) return;

    try {
      await _savedProjectRef(userId, projectId).update({
        'status': ProjectLifecycle.statusForStage(derived),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      _applied.remove(guard);
    }
  }

  /// Marks the planning and canvassing cycle done (materials planned, supplier
  /// selected). This is not a construction milestone.
  Future<void> markCompleted({
    required String userId,
    required String projectId,
  }) async {
    await _savedProjectRef(userId, projectId).update({
      'status': ProjectLifecycle.completed,
      'completedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Reopens a completed cycle, e.g. to canvass another supplier.
  Future<void> reopen({
    required String userId,
    required String projectId,
    required Map<String, dynamic>? post,
  }) async {
    final stage = post == null
        ? ProjectLifecycle.stagePlanning
        : ProjectLifecycle.stageFromPost(post);

    await _savedProjectRef(userId, projectId).update({
      'status': ProjectLifecycle.statusForStage(stage),
      'completedAt': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    _applied.removeWhere((key) => key.startsWith('$userId/$projectId:'));
  }

  /// Records the selected supplier on the builder's saved estimate.
  Future<void> markSupplierSelected({
    required String userId,
    required String projectId,
    String? shopName,
  }) async {
    await _savedProjectRef(userId, projectId).update({
      'status': ProjectLifecycle.supplierSelected,
      if (shopName != null && shopName.isNotEmpty) 'selectedShopName': shopName,
      'supplierSelectedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
