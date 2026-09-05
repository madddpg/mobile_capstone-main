import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:iconstruct/core/firebase/firestore_error.dart';
import 'package:iconstruct/features/auth/presentation/screens/material_estimator.dart';
import 'package:iconstruct/core/models/project_model.dart';
import 'package:iconstruct/features/bidding/screens/project_bids_screen.dart';
import 'package:iconstruct/features/project_creation/data/project_lifecycle.dart';
import 'package:iconstruct/features/project_creation/data/project_status_service.dart';
import 'package:iconstruct/core/widgets/app_message.dart';

class ProjectTrackingScreen extends StatelessWidget {
  const ProjectTrackingScreen({super.key});

  static const Color _cream = Color(0xFFEDE4D4);
  static const Color _darkBlue = Color(0xFF2C3E50);
  static const Color _midBlue = Color(0xFF648DB6);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_darkBlue, Color(0xFF4F6B8A), _midBlue],
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_back_ios_new,
                        color: Colors.white,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Expanded(
                      child: Text(
                        'Project Tracking',
                        style: GoogleFonts.inter(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: _cream,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 4, 28, 16),
                child: Text(
                  'Monitor progress from draft through supplier selection.',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: _cream.withValues(alpha: 0.75),
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: _cream,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                  ),
                  child: user == null
                      ? Center(
                          child: Text(
                            'Please log in to track projects.',
                            style: GoogleFonts.poppins(color: _darkBlue),
                          ),
                        )
                      : StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('users')
                              .doc(user.uid)
                              .collection('saved_projects')
                              .orderBy('updatedAt', descending: true)
                              .snapshots(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                child: CircularProgressIndicator(
                                  color: _darkBlue,
                                ),
                              );
                            }

                            if (snapshot.hasError) {
                              return Center(
                                child: Text(
                                  'Unable to load projects.',
                                  style: GoogleFonts.poppins(color: _darkBlue),
                                ),
                              );
                            }

                            final docs = snapshot.data?.docs ?? [];
                            if (docs.isEmpty) {
                              return Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(32),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.timeline_outlined,
                                        size: 48,
                                        color: _darkBlue.withValues(alpha: 0.4),
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'No projects yet',
                                        style: GoogleFonts.poppins(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: _darkBlue,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Start a new renovation to begin tracking.',
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.poppins(
                                          fontSize: 13,
                                          color: _darkBlue.withValues(alpha: 0.6),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }

                            return ListView.separated(
                              padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                              itemCount: docs.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 16),
                              itemBuilder: (context, index) {
                                final project =
                                    ProjectModel.fromDocument(docs[index]);
                                return _TrackingCard(
                                  project: project,
                                  userId: user.uid,
                                );
                              },
                            );
                          },
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrackingCard extends StatelessWidget {
  final ProjectModel project;
  final String userId;

  const _TrackingCard({required this.project, required this.userId});

  static const Color _darkBlue = Color(0xFF2C3E50);

  @override
  Widget build(BuildContext context) {
    final postId = project.postId;
    if (postId == null || postId.isEmpty) {
      return _card(context, stage: ProjectLifecycle.stageIndex(project.status));
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('projectPosts')
          .doc(postId)
          .snapshots(),
      builder: (context, snapshot) {
        final post = snapshot.data?.data();
        final storedStage = ProjectLifecycle.stageIndex(project.status);
        var stage = storedStage;
        var bidCount = 0;

        if (post != null) {
          final rawCount = post['quotationCount'];
          bidCount = rawCount is num
              ? rawCount.toInt()
              : int.tryParse('${rawCount ?? 0}') ?? 0;

          final derived = ProjectLifecycle.stageFromPost(post);
          if (derived > storedStage &&
              storedStage < ProjectLifecycle.stageCompleted) {
            stage = derived;
            _scheduleSync(post);
          }
        }

        return _card(
          context,
          stage: stage,
          bidCount: bidCount,
          post: post,
        );
      },
    );
  }

  void _scheduleSync(Map<String, dynamic> post) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ProjectStatusService.instance.syncFromPost(
        userId: userId,
        projectId: project.id,
        storedStatus: project.status,
        post: post,
      );
    });
  }

  Widget _card(
    BuildContext context, {
    required int stage,
    int bidCount = 0,
    Map<String, dynamic>? post,
  }) {
    final display = ProjectLifecycle.stageLabels[stage];
    final status = ProjectLifecycle.statusForStage(stage);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      elevation: 1,
      shadowColor: Colors.black26,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _openProject(context, stage),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      project.projectName.isNotEmpty
                          ? project.projectName
                          : project.projectType,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _darkBlue,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _statusChipColor(stage),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      display,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _statusTextColor(stage),
                      ),
                    ),
                  ),
                ],
              ),
              if (project.projectType.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  project.projectType,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: _darkBlue.withValues(alpha: 0.55),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              _LifecycleTimeline(currentIndex: stage),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.inventory_2_outlined,
                    size: 14,
                    color: _darkBlue.withValues(alpha: 0.5),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${project.materialCount} materials',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: _darkBlue.withValues(alpha: 0.6),
                    ),
                  ),
                  if (bidCount > 0) ...[
                    const SizedBox(width: 12),
                    Icon(
                      Icons.local_offer_outlined,
                      size: 14,
                      color: const Color(0xFF059669).withValues(alpha: 0.9),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$bidCount quotation${bidCount == 1 ? '' : 's'}',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF047857),
                      ),
                    ),
                  ],
                  const Spacer(),
                  Text(
                    'Tap to open',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF648DB6),
                    ),
                  ),
                ],
              ),
              if (ProjectLifecycle.canMarkComplete(status)) ...[
                const SizedBox(height: 12),
                _CompleteAction(
                  label: 'Mark planning complete',
                  icon: Icons.task_alt_rounded,
                  onPressed: () => _confirmComplete(context),
                ),
              ] else if (stage == ProjectLifecycle.stageCompleted) ...[
                const SizedBox(height: 12),
                _CompleteAction(
                  label: 'Reopen canvassing',
                  icon: Icons.refresh_rounded,
                  filled: false,
                  onPressed: () => _reopen(context, post),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmComplete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          'Mark planning complete?',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Materials are planned and a supplier is selected, so this planning '
          'and canvassing cycle is done. You can reopen it later to canvass '
          'again.',
          style: GoogleFonts.poppins(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Mark complete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ProjectStatusService.instance.markCompleted(
        userId: userId,
        projectId: project.id,
      );
      if (!context.mounted) return;
      showAppMessage(
        context,
        const SnackBar(content: Text('Planning cycle marked complete.')),
        kind: AppMessageKind.success,
      );
    } catch (e) {
      if (!context.mounted) return;
      showAppMessage(context,
        SnackBar(
          content: Text(firestoreUserMessage(e, action: 'update this estimate')),
        ),
      );
    }
  }

  Future<void> _reopen(
    BuildContext context,
    Map<String, dynamic>? post,
  ) async {
    try {
      await ProjectStatusService.instance.reopen(
        userId: userId,
        projectId: project.id,
        post: post,
      );
      if (!context.mounted) return;
      showAppMessage(
        context,
        const SnackBar(content: Text('Canvassing reopened.')),
        kind: AppMessageKind.success,
      );
    } catch (e) {
      if (!context.mounted) return;
      showAppMessage(context,
        SnackBar(
          content: Text(firestoreUserMessage(e, action: 'reopen canvassing')),
        ),
      );
    }
  }

  Color _statusChipColor(int stage) {
    switch (stage) {
      case 0:
        return Colors.grey.shade200;
      case 1:
        return const Color(0xFFE0E7FF);
      case 2:
        return const Color(0xFFFEF3C7);
      case 3:
        return const Color(0xFFFFEDD5);
      case 4:
        return const Color(0xFFD1FAE5);
      case 5:
        return const Color(0xFFBBF7D0);
      default:
        return Colors.grey.shade200;
    }
  }

  Color _statusTextColor(int stage) {
    switch (stage) {
      case 0:
        return Colors.grey.shade800;
      case 1:
        return const Color(0xFF3730A3);
      case 2:
        return const Color(0xFF92400E);
      case 3:
        return const Color(0xFF9A3412);
      case 4:
        return const Color(0xFF065F46);
      case 5:
        return const Color(0xFF166534);
      default:
        return Colors.grey.shade800;
    }
  }

  void _openProject(BuildContext context, int stage) {
    final postId = project.postId;
    if (stage >= ProjectLifecycle.stageWaiting && postId != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProjectBidsScreen(
            postId: postId,
            projectName: project.projectName,
          ),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MaterialEstimatorScreen(
          projectName: project.projectType.isNotEmpty
              ? project.projectType
              : project.projectName,
          existingProject: project,
        ),
      ),
    );
  }
}

class _CompleteAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool filled;
  final VoidCallback onPressed;

  const _CompleteAction({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.filled = true,
  });

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF047857);

    return SizedBox(
      width: double.infinity,
      child: filled
          ? ElevatedButton.icon(
              onPressed: onPressed,
              icon: Icon(icon, size: 18),
              label: Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            )
          : OutlinedButton.icon(
              onPressed: onPressed,
              icon: Icon(icon, size: 18),
              label: Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: accent,
                side: BorderSide(color: accent.withValues(alpha: 0.5)),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
    );
  }
}

class _LifecycleTimeline extends StatelessWidget {
  final int currentIndex;

  const _LifecycleTimeline({required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    final stageCount = ProjectLifecycle.stageLabels.length;

    return Column(
      children: [
        Row(
          children: List.generate(stageCount * 2 - 1, (i) {
            if (i.isOdd) {
              final leftStage = i ~/ 2;
              final done = leftStage < currentIndex;
              return Expanded(
                child: Container(
                  height: 3,
                  color: done
                      ? const Color(0xFF059669)
                      : Colors.grey.shade300,
                ),
              );
            }
            final stage = i ~/ 2;
            final done = stage <= currentIndex;
            return Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done ? const Color(0xFF059669) : Colors.grey.shade300,
                border: stage == currentIndex
                    ? Border.all(color: const Color(0xFF2C3E50), width: 2)
                    : null,
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (final label in ProjectLifecycle.shortLabels) _miniLabel(label),
          ],
        ),
      ],
    );
  }

  Widget _miniLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.poppins(
        fontSize: 9,
        fontWeight: FontWeight.w500,
        color: const Color(0xFF2C3E50).withValues(alpha: 0.55),
      ),
    );
  }
}
