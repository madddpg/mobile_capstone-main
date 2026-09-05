import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:iconstruct/core/firebase/firestore_error.dart';
import 'package:iconstruct/core/models/project_model.dart';
import 'package:iconstruct/core/navigation/planning_nav.dart';
import 'package:iconstruct/core/state/active_project_state.dart';
import 'package:iconstruct/features/bidding/screens/posted_project_details_screen.dart';
import 'package:iconstruct/features/bidding/screens/project_bids_screen.dart';
import 'package:iconstruct/core/widgets/iconstruct_panel.dart';
import 'package:iconstruct/core/widgets/offset_panel_shell.dart';
import 'package:iconstruct/features/project_creation/data/bom_export.dart';
import 'package:iconstruct/features/project_creation/data/project_lifecycle.dart';
import 'package:iconstruct/features/project_creation/widgets/bom_share_sheet.dart';
import 'package:iconstruct/core/widgets/app_message.dart';

/// How [SavedProjectsScreen] focuses the list for different home entry points.
enum SavedProjectsFocus {
  /// All saved estimates (My Projects).
  all,

  /// Estimates that still need quotations requested (Post for Bidding).
  readyToPost,
}

/// Client-side sort for the saved estimates list.
enum SavedProjectsSort {
  newestUpdated,
  oldestUpdated,
  nameAsc,
  nameDesc,
  status,
  areaHigh,
  areaLow,
}

extension on SavedProjectsSort {
  String get label => switch (this) {
        SavedProjectsSort.newestUpdated => 'Newest updated',
        SavedProjectsSort.oldestUpdated => 'Oldest updated',
        SavedProjectsSort.nameAsc => 'Name A–Z',
        SavedProjectsSort.nameDesc => 'Name Z–A',
        SavedProjectsSort.status => 'Planning status',
        SavedProjectsSort.areaHigh => 'Largest area',
        SavedProjectsSort.areaLow => 'Smallest area',
      };

  List<ProjectModel> apply(List<ProjectModel> source) {
    final list = List<ProjectModel>.from(source);
    int byName(ProjectModel a, ProjectModel b) =>
        a.projectName.toLowerCase().compareTo(b.projectName.toLowerCase());

    switch (this) {
      case SavedProjectsSort.newestUpdated:
        list.sort((a, b) => b.lastUpdated.compareTo(a.lastUpdated));
      case SavedProjectsSort.oldestUpdated:
        list.sort((a, b) => a.lastUpdated.compareTo(b.lastUpdated));
      case SavedProjectsSort.nameAsc:
        list.sort(byName);
      case SavedProjectsSort.nameDesc:
        list.sort((a, b) => byName(b, a));
      case SavedProjectsSort.status:
        list.sort((a, b) {
          final stage = ProjectLifecycle.stageIndex(
            b.status,
          ).compareTo(ProjectLifecycle.stageIndex(a.status));
          if (stage != 0) return stage;
          return b.lastUpdated.compareTo(a.lastUpdated);
        });
      case SavedProjectsSort.areaHigh:
        list.sort((a, b) => b.projectArea.compareTo(a.projectArea));
      case SavedProjectsSort.areaLow:
        list.sort((a, b) => a.projectArea.compareTo(b.projectArea));
    }
    return list;
  }
}

// --- Screen ---
class SavedProjectsScreen extends StatefulWidget {
  final SavedProjectsFocus focus;

  const SavedProjectsScreen({
    super.key,
    this.focus = SavedProjectsFocus.all,
  });

  @override
  State<SavedProjectsScreen> createState() => _SavedProjectsScreenState();
}

class _SavedProjectsScreenState extends State<SavedProjectsScreen> {
  SavedProjectsSort _sort = SavedProjectsSort.newestUpdated;
  int _reloadNonce = 0;

  void _retryLoad() {
    setState(() => _reloadNonce++);
  }

  @override
  Widget build(BuildContext context) {
    const Color creamBg = Color(0xFFEDE4D4);
    final isPostFocus = widget.focus == SavedProjectsFocus.readyToPost;

    return OffsetPanelShell(
      extent: OffsetPanelExtent.fillBottom,
      safeAreaBottom: false,
      activeNav: OffsetNavTab.files,
      panelColor: IConstructPanel.darkBlue,
      contentPadding: EdgeInsets.zero,
      header: OffsetPanelHeaders.backOnly(context),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 28),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    isPostFocus ? 'Request Quotations' : 'Saved Projects',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      color: creamBg,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                _SortControl(
                  value: _sort,
                  onChanged: (next) => setState(() => _sort = next),
                ),
              ],
            ),
          ),
          if (isPostFocus) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Text(
                'Pick an estimate that is ready, then use Post to canvass hardware shops. Bids stay private between you and each shop.',
                style: TextStyle(
                  color: creamBg.withValues(alpha: 0.85),
                  fontSize: 13,
                  height: 1.35,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Text(
              'Sorted by ${_sort.label.toLowerCase()}',
              style: TextStyle(
                color: creamBg.withValues(alpha: 0.65),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Container(
              height: 1,
              color: creamBg.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: StreamBuilder<User?>(
              stream: FirebaseAuth.instance.authStateChanges(),
              builder: (context, authSnapshot) {
                final user = authSnapshot.data;
                if (authSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: creamBg),
                  );
                }
                if (user == null) {
                  return Center(
                    child: Text(
                      'Please log in to view saved estimates.',
                      style: TextStyle(
                        color: creamBg.withAlpha(150),
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  );
                }

                return StreamBuilder<QuerySnapshot>(
                  key: ValueKey('saved-projects-$_reloadNonce-${user.uid}'),
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(user.uid)
                      .collection('saved_projects')
                      .orderBy('updatedAt', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(color: creamBg),
                      );
                    }

                    if (snapshot.hasError) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                firestoreUserMessage(
                                  snapshot.error!,
                                  action: 'load saved projects',
                                ),
                                style: TextStyle(
                                  color: creamBg.withAlpha(180),
                                  fontSize: 14,
                                  height: 1.4,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              TextButton(
                                onPressed: _retryLoad,
                                child: const Text(
                                  'Try again',
                                  style: TextStyle(
                                    color: creamBg,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Text(
                            isPostFocus
                                ? 'No estimates ready to canvass yet. Create a material list first, then come back here to request quotations.'
                                : 'No saved projects yet.',
                            style: TextStyle(
                              color: creamBg.withAlpha(150),
                              fontSize: 16,
                              height: 1.4,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    }

                    final allProjects = snapshot.data!.docs
                        .map((doc) => ProjectModel.fromDocument(doc))
                        .toList();

                    // Post-for-bidding: estimates with materials that are not
                    // already on the canvassing board.
                    final filtered = isPostFocus
                        ? allProjects
                            .where(
                              (p) =>
                                  p.materials.isNotEmpty && p.postId == null,
                            )
                            .toList()
                        : allProjects;

                    final projects = _sort.apply(filtered);

                    if (projects.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Text(
                            isPostFocus
                                ? 'Every estimate with materials is already posted, or still needs materials. Open My Projects to review them.'
                                : 'No saved projects yet.',
                            style: TextStyle(
                              color: creamBg.withAlpha(150),
                              fontSize: 16,
                              height: 1.4,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    }

                    return AnimatedBuilder(
                      animation: ActiveProjectState.instance,
                      builder: (context, child) {
                        return ListView.builder(
                          padding: const EdgeInsets.only(
                            left: 20,
                            right: 20,
                            top: 8,
                            bottom: 120,
                          ),
                          itemCount: projects.length,
                          itemBuilder: (context, index) {
                            final project = projects[index];
                            return ProjectCard(
                              project: project,
                              isActive: project.id ==
                                  ActiveProjectState
                                      .instance.activeProject?.id,
                              emphasizePost: isPostFocus,
                            );
                          },
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SortControl extends StatelessWidget {
  final SavedProjectsSort value;
  final ValueChanged<SavedProjectsSort> onChanged;

  const _SortControl({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const creamBg = Color(0xFFEDE4D4);

    return PopupMenuButton<SavedProjectsSort>(
      tooltip: 'Sort estimates',
      initialValue: value,
      onSelected: onChanged,
      offset: const Offset(0, 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      color: creamBg,
      itemBuilder: (context) => [
        for (final option in SavedProjectsSort.values)
          PopupMenuItem(
            value: option,
            child: Row(
              children: [
                Icon(
                  option == value
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  size: 18,
                  color: const Color(0xFF2A3E4E),
                ),
                const SizedBox(width: 10),
                Text(
                  option.label,
                  style: TextStyle(
                    color: const Color(0xFF2A3E4E),
                    fontWeight:
                        option == value ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
      ],
      child: Semantics(
        button: true,
        label: 'Sort estimates',
        hint: 'Currently ${_sortHint(value)}',
        child: Material(
          color: creamBg.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.sort_rounded,
                  size: 20,
                  color: creamBg.withValues(alpha: 0.95),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.expand_more_rounded,
                  size: 18,
                  color: creamBg.withValues(alpha: 0.85),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _sortHint(SavedProjectsSort sort) => sort.label;
}

// --- Reusable Card ---
class ProjectCard extends StatelessWidget {
  final ProjectModel project;
  final bool isActive;
  final bool emphasizePost;

  const ProjectCard({
    super.key,
    required this.project,
    this.isActive = false,
    this.emphasizePost = false,
  });

  String _formatTimeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 60) return 'Updated ${diff.inMinutes} mins ago';
    if (diff.inHours < 24) return 'Updated ${diff.inHours} hours ago';
    return 'Updated ${diff.inDays} days ago';
  }

  Color _getStatusColor(String status) {
    switch (ProjectLifecycle.stageIndex(status)) {
      case ProjectLifecycle.stagePlanning:
        return Colors.blue.shade100;
      case ProjectLifecycle.stageWaiting:
        return const Color(0xFFFEF3C7);
      case ProjectLifecycle.stageReceiving:
        return const Color(0xFFFFEDD5);
      case ProjectLifecycle.stageSupplierSelected:
        return const Color(0xFFD1FAE5);
      case ProjectLifecycle.stageCompleted:
        return const Color(0xFFBBF7D0);
      case ProjectLifecycle.stageDraft:
      default:
        return Colors.grey.shade300;
    }
  }

  Color _getStatusTextColor(String status) {
    switch (ProjectLifecycle.stageIndex(status)) {
      case ProjectLifecycle.stagePlanning:
        return Colors.blue.shade900;
      case ProjectLifecycle.stageWaiting:
        return const Color(0xFF92400E);
      case ProjectLifecycle.stageReceiving:
        return const Color(0xFF9A3412);
      case ProjectLifecycle.stageSupplierSelected:
        return const Color(0xFF065F46);
      case ProjectLifecycle.stageCompleted:
        return const Color(0xFF166534);
      case ProjectLifecycle.stageDraft:
      default:
        return Colors.grey.shade800;
    }
  }

  String _getCostEmoji(String costLevel) {
    switch (costLevel.toLowerCase()) {
      case 'high':
        return '🔴';
      case 'low':
        return '🟢';
      case 'medium':
      default:
        return '🟡';
    }
  }

  void _handlePostProject(BuildContext context) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    if (project.postId != null ||
        ProjectLifecycle.stageIndex(project.status) >=
            ProjectLifecycle.stageWaiting) {
      showAppMessage(context, 
        const SnackBar(
          content: Text('This project is already posted for bidding.'),
        ),
      );
      return;
    }

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await FirebaseAuth.instance.currentUser?.getIdToken(true);

      final batch = FirebaseFirestore.instance.batch();
      final newPostRef = FirebaseFirestore.instance
          .collection('projectPosts')
          .doc();
      final savedProjectRef = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('saved_projects')
          .doc(project.id);

      final Map<String, dynamic> projectPostData = {
        'postId': newPostRef.id,
        'userId': uid,
        'builderId': uid,
        'projectId': project.id,
        'projectName': project.projectName,
        'projectType': project.projectType,
        'materials': project.materials,
        'materialsCount': project.materialCount,
        'totalAreaSqm': project.projectArea,
        'budget': project.costLevel,
        'status': 'open',
        'quotationCount': 0,
        'postedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      batch.set(newPostRef, projectPostData);
      batch.set(
        savedProjectRef,
        {
          'status': ProjectLifecycle.waitingForQuotations,
          'postId': newPostRef.id,
          'postedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      await batch.commit();

      ActiveProjectState.instance.clear();

      if (context.mounted) {
        Navigator.pop(context); // Remove loading
        showAppMessage(
          context,
          const SnackBar(
            content: Text('Project successfully posted for bidding!'),
          ),
          kind: AppMessageKind.success,
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Remove loading
        showAppMessage(context, 
          SnackBar(
            content: Text(
              firestoreUserMessage(e, action: 'post this estimate for bidding'),
            ),
            duration: const Duration(seconds: 6),
          ),
        );
      }
    }
  }

  void _handleShareProject(BuildContext context) {
    showBomShareSheet(
      context,
      BomExportData.fromMaterials(
        estimateName: project.projectName,
        renovationType: project.projectType,
        areaSqm: project.projectArea,
        budgetPreference: project.costLevel,
        materials: project.materials,
      ),
    );
  }

  void _handleDeleteProject(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final materialCount = project.materials.length;
    final isPosted = project.postId != null;
    final lossLines = <String>[
      if (materialCount > 0)
        '$materialCount material${materialCount == 1 ? '' : 's'} in this estimate'
      else
        'This empty estimate draft',
      if (isPosted)
        'Your saved copy only — the open bidding post stays live until you withdraw it'
      else
        'This estimate cannot be recovered after delete',
    ];

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: const Color(0xFFEDE4D4),
          title: Text(
            'Delete "${project.projectName}"?',
            style: const TextStyle(
              color: Color(0xFF2A3E4E),
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'You will lose:',
                style: TextStyle(
                  color: Color(0xFF2A3E4E),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              ...lossLines.map(
                (line) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('•  ', style: TextStyle(color: Color(0xFF5A6E7E))),
                      Expanded(
                        child: Text(
                          line,
                          style: const TextStyle(color: Color(0xFF5A6E7E)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Keep estimate',
                style: TextStyle(color: Color(0xFF5A6E7E)),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade400,
              ),
              onPressed: () async {
                Navigator.pop(context);
                try {
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(uid)
                      .collection('saved_projects')
                      .doc(project.id)
                      .delete();

                  if (context.mounted) {
                    showAppMessage(
                      context,
                      const SnackBar(
                        content: Text('Estimate deleted.'),
                      ),
                      kind: AppMessageKind.success,
                    );

                    if (isActive) {
                      ActiveProjectState.instance.setActiveProject(null);
                    }
                  }
                } catch (e) {
                  if (context.mounted) {
                    showAppMessage(context, 
                      SnackBar(
                        content: Text(
                          firestoreUserMessage(
                            e,
                            action: 'delete this estimate',
                          ),
                        ),
                      ),
                    );
                  }
                }
              },
              child: const Text(
                'Delete permanently',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color cardBg = Color(0xFFEDE4D4); // Match cream background precisely
    const Color textDark = Color(0xFF2A3E4E);
    const Color textMuted = Color(0xFF5A6E7E);

    // Prepare material preview string (support structured items)
    final previewMaterials = project.materials
        .take(3)
        .map((m) => m is Map ? (m['name'] ?? '').toString() : m.toString())
        .where((s) => s.isNotEmpty)
        .join(', ');
    final remainingCount = project.materials.length > 3
        ? project.materials.length - 3
        : 0;
    final materialsText = remainingCount > 0
        ? '$previewMaterials +$remainingCount more'
        : previewMaterials;
    final hasMaterials = project.materials.isNotEmpty;

    return GestureDetector(
      onTap: () {
        if (project.postId == null) {
          showAppMessage(context, 
            const SnackBar(content: Text('This project is not posted yet.')),
          );
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProjectBidsScreen(
                postId: project.postId!,
                projectName: project.projectName,
              ),
            ),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 24),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(28),
          border: isActive
              ? Border.all(color: const Color(0xFF648DB6), width: 3)
              : null,
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 12,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Top Row: Small Title Label & Action Menu
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text(
                  'Project Name',
                  style: TextStyle(
                    color: textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                ),
                // Card action zone: quick download sits beside the overflow menu
                // so it never competes with the project name for width.
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Semantics(
                      button: true,
                      label: 'Download material list',
                      hint: 'Save, print, or share ${project.projectName}',
                      child: Tooltip(
                        message: hasMaterials
                            ? 'Download material list'
                            : 'Add materials to download this list',
                        child: Material(
                          color: textDark.withValues(
                            alpha: hasMaterials ? 0.08 : 0.04,
                          ),
                          borderRadius: BorderRadius.circular(11),
                          child: InkWell(
                            onTap: () => _handleShareProject(context),
                            borderRadius: BorderRadius.circular(11),
                            splashColor: textDark.withValues(alpha: 0.16),
                            child: SizedBox(
                              width: 34,
                              height: 34,
                              child: Icon(
                                Icons.download_rounded,
                                size: 20,
                                color: textDark.withValues(
                                  alpha: hasMaterials ? 0.9 : 0.35,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 2),
                    // Three-dot Quick Actions Menu
                    SizedBox(
                      height: 34,
                      width: 30,
                      child: PopupMenuButton<String>(
                        padding: EdgeInsets.zero,
                        icon: const Icon(
                          Icons.more_vert,
                          color: textDark,
                          size: 22,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        itemBuilder: (context) {
                          final posted = ProjectLifecycle.isPosted(
                            project.status,
                            postId: project.postId,
                          );
                          return [
                            PopupMenuItem(
                              value: posted ? 'view' : 'edit',
                              child: Row(
                                children: [
                                  Icon(
                                    posted
                                        ? Icons.visibility_outlined
                                        : Icons.edit_outlined,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(posted ? 'View display' : 'Edit'),
                                ],
                              ),
                            ),
                            if (!posted)
                              const PopupMenuItem(
                                value: 'post',
                                child: Row(
                                  children: [
                                    Icon(Icons.upload_outlined, size: 20),
                                    SizedBox(width: 10),
                                    Text('Post'),
                                  ],
                                ),
                              ),
                            const PopupMenuItem(
                              value: 'share',
                              child: Row(
                                children: [
                                  Icon(Icons.ios_share_rounded, size: 20),
                                  SizedBox(width: 10),
                                  Text('Share list'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.delete_outline,
                                    color: Colors.red,
                                    size: 20,
                                  ),
                                  SizedBox(width: 10),
                                  Text(
                                    'Delete',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ],
                              ),
                            ),
                          ];
                        },
                        onSelected: (value) {
                          if (value == 'edit') {
                            PlanningNav.openMaterialEstimator(
                              context,
                              projectName: project.projectName,
                              existingProject: project,
                            );
                          } else if (value == 'view') {
                            final postId = project.postId;
                            if (postId == null || postId.isEmpty) return;
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    PostedProjectDetailsScreen(postId: postId),
                              ),
                            );
                          } else if (value == 'post') {
                            _handlePostProject(context);
                          } else if (value == 'share') {
                            _handleShareProject(context);
                          } else if (value == 'delete') {
                            _handleDeleteProject(context);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // 2. Project Title & Status Badge
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    project.projectName,
                    style: const TextStyle(
                      color: textDark,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Status Badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusColor(project.status),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    ProjectLifecycle.cardLabel(project.status).toUpperCase(),
                    style: TextStyle(
                      color: _getStatusTextColor(project.status),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // 3. Project Type / Category
            Text(
              project.projectType,
              style: const TextStyle(
                color: textMuted,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: 10),

            if (project.postId != null &&
                ProjectLifecycle.stageIndex(project.status) >=
                    ProjectLifecycle.stageWaiting)
              StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('projectPosts')
                    .doc(project.postId)
                    .snapshots(),
                builder: (context, snapshot) {
                  final data = snapshot.data?.data() as Map<String, dynamic>?;
                  final rawCount = data?['quotationCount'];
                  final int count =
                      rawCount is num ? rawCount.toInt() : 0;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ProjectLifecycle.nextAction(
                          project.status,
                          bidCount: count,
                        ),
                        style: TextStyle(
                          color: textMuted.withValues(alpha: 0.95),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          height: 1.3,
                        ),
                      ),
                      if (snapshot.hasData && snapshot.data!.exists) ...[
                        const SizedBox(height: 10),
                        Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: count > 0
                                ? Colors.green.shade100
                                : Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.local_offer_outlined,
                                size: 16,
                                color: count > 0
                                    ? Colors.green.shade700
                                    : Colors.grey.shade700,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '$count bid${count == 1 ? '' : 's'}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: count > 0
                                      ? Colors.green.shade700
                                      : Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 6),
                    ],
                  );
                },
              )
            else ...[
              Text(
                ProjectLifecycle.nextAction(project.status),
                style: TextStyle(
                  color: textMuted.withValues(alpha: 0.95),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 12),
            ],

            // 4. Key Project Summary
            Text(
              '${project.materialCount} Materials • ${project.projectArea.toStringAsFixed(2)} sq.m • ${_getCostEmoji(project.costLevel)} ${project.costLevel} Cost',
              style: const TextStyle(
                color: textDark,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),

            // 5. Material Preview (Inline stylized text)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.6),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.inventory_2_outlined,
                    size: 16,
                    color: textMuted,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      materialsText,
                      style: const TextStyle(
                        color: textMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            if (emphasizePost) ...[
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton.icon(
                  onPressed: () => _handlePostProject(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: textDark,
                    foregroundColor: cardBg,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.campaign_outlined, size: 18),
                  label: const Text(
                    'Request quotations',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // 6. Last Updated
            Row(
              children: [
                const Icon(Icons.access_time, size: 14, color: Colors.grey),
                const SizedBox(width: 6),
                Text(
                  _formatTimeAgo(project.lastUpdated),
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
