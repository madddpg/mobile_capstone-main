import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:iconstruct/core/models/project_model.dart';

class ActiveProjectState extends ChangeNotifier {
  // Singleton instance for lightweight global state access
  static final ActiveProjectState instance = ActiveProjectState._internal();
  ActiveProjectState._internal();

  ProjectModel? _activeProject;

  ProjectModel? get activeProject => _activeProject;

  /// Loads the persisted active project from Firestore on app startup or post-login.
  Future<void> loadFromFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (userDoc.exists && userDoc.data()!.containsKey('activeProjectId')) {
        final activeId = userDoc.data()!['activeProjectId'];
        if (activeId != null) {
          final projectDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('saved_projects')
              .doc(activeId)
              .get();

          if (projectDoc.exists) {
            _activeProject = ProjectModel.fromDocument(projectDoc);
            notifyListeners();
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading active project: $e');
    }
  }

  /// Sets the currently selected active project and optionally persists it to Firestore
  void setActiveProject(ProjectModel? project) async {
    _activeProject = project;
    notifyListeners();

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      if (project != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'activeProjectId': project.id,
        }, SetOptions(merge: true));
      } else {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'activeProjectId': FieldValue.delete(),
        }, SetOptions(merge: true));
      }
    }
  }

  /// Clears the active project when navigating away or skipping
  void clear() {
    setActiveProject(null);
  }
}
