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

  /// Detaches saved estimates from a bidding post that can no longer be read.
  ///
  /// A post can disappear or change hands outside the app, through the
  /// Firebase console or the shop dashboard writing with the Admin SDK. The
  /// saved project then keeps pointing at it: its card still says it is
  /// waiting for quotations, and every tap ends at the same error. This clears
  /// the link and returns the project to planning, keeping its materials, so
  /// the builder can post it again.
  ///
  /// Matches on the stored postId rather than on a project id, because the
  /// unreadable post is where that project id would otherwise have come from.
  /// Returns how many saved projects were updated.
  Future<int> unlinkPost({
    required String userId,
    required String postId,
  }) async {
    final matches = await _firestore
        .collection('users')
        .doc(userId)
        .collection('saved_projects')
        .where('postId', isEqualTo: postId)
        .get();
    if (matches.docs.isEmpty) return 0;

    final batch = _firestore.batch();
    for (final doc in matches.docs) {
      batch.update(doc.reference, {
        'postId': FieldValue.delete(),
        'postedAt': FieldValue.delete(),
        'selectedShopName': FieldValue.delete(),
        'supplierSelectedAt': FieldValue.delete(),
        'status': ProjectLifecycle.planning,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _applied.removeWhere((key) => key.startsWith('$userId/${doc.id}:'));
    }
    await batch.commit();
    return matches.docs.length;
  }
}
