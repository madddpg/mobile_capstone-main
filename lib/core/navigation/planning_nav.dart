import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:iconstruct/core/models/project_model.dart';
import 'package:iconstruct/core/state/active_project_state.dart';
import 'package:iconstruct/features/auth/presentation/screens/home_screen.dart';
import 'package:iconstruct/features/auth/presentation/screens/material_estimator.dart';
import 'package:iconstruct/features/auth/presentation/screens/saved_projects.dart';
import 'package:iconstruct/features/bidding/screens/quotations_screen.dart';
import 'package:iconstruct/features/project_creation/data/project_lifecycle.dart';
import 'package:iconstruct/core/widgets/app_message.dart';

/// Cross-screen navigation for the planning / finalize flow.
///
/// Lives outside feature screens so `saved_projects` and `material_estimator`
/// do not import each other (avoids circular library dependencies).
class PlanningNav {
  const PlanningNav._();

  static Future<void> openSavedProjects(BuildContext context) {
    return Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SavedProjectsScreen()),
    );
  }

  static Future<void> startNewEstimate(BuildContext context) {
    return Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  static Future<void> openMaterialEstimator(
    BuildContext context, {
    required String projectName,
    ProjectModel? existingProject,
  }) {
    return Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MaterialEstimatorScreen(
          projectName: projectName,
          existingProject: existingProject,
        ),
      ),
    );
  }

  /// Opens the builder's most recently updated unfinished estimate.
  ///
  /// Draft / planning → BOM review. Waiting / receiving bids → quotations.
  /// Skips supplier-selected and completed estimates.
  static Future<void> continueLastEstimate(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _toast(context, 'Sign in to continue an estimate.');
      return;
    }

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: Color(0xFFEDE4D4)),
      ),
    );

    try {
      ProjectModel? last = _planningOrNull(
        ActiveProjectState.instance.activeProject,
      );

      if (last == null) {
        final snap = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('saved_projects')
            .orderBy('updatedAt', descending: true)
            .limit(20)
            .get();

        for (final doc in snap.docs) {
          final candidate = _planningOrNull(ProjectModel.fromDocument(doc));
          if (candidate != null) {
            last = candidate;
            break;
          }
        }

        // No draft in progress — resume the latest posted estimate's bids.
        if (last == null) {
          for (final doc in snap.docs) {
            final candidate =
                _unfinishedOrNull(ProjectModel.fromDocument(doc));
            if (candidate != null) {
              last = candidate;
              break;
            }
          }
        }
      }

      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();

      if (last == null) {
        _toast(context, 'No estimate in progress. Start a new one.');
        return;
      }

      final project = last;
      ActiveProjectState.instance.setActiveProject(project);

      final stage = ProjectLifecycle.stageIndex(project.status);
      final postId = project.postId;
      if (stage >= ProjectLifecycle.stageWaiting &&
          postId != null &&
          postId.isNotEmpty) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => QuotationsScreen(
              postId: postId,
              projectName: project.projectName.isNotEmpty
                  ? project.projectName
                  : project.projectType,
            ),
          ),
        );
        return;
      }

      await openMaterialEstimator(
        context,
        projectName: project.projectType.isNotEmpty
            ? project.projectType
            : project.projectName,
        existingProject: project,
      );
    } catch (_) {
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      _toast(context, 'Could not open your last estimate. Try again.');
    }
  }

  static ProjectModel? _planningOrNull(ProjectModel? project) {
    if (project == null) return null;
    if (ProjectLifecycle.isPosted(project.status, postId: project.postId)) {
      return null;
    }
    return project;
  }

  static ProjectModel? _unfinishedOrNull(ProjectModel? project) {
    if (project == null) return null;
    final stage = ProjectLifecycle.stageIndex(project.status);
    if (stage >= ProjectLifecycle.stageSupplierSelected) return null;
    return project;
  }

  static void _toast(BuildContext context, String message) {
    showAppMessage(context, 
      SnackBar(content: Text(message)),
    );
  }
}
