import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:iconstruct/core/firebase/firestore_error.dart';
import 'package:iconstruct/core/models/project_model.dart';
import 'package:iconstruct/core/navigation/planning_nav.dart';
import 'package:iconstruct/core/state/active_project_state.dart';
import 'package:iconstruct/core/widgets/iconstruct_panel.dart';
import 'package:iconstruct/core/widgets/offset_pill_nav.dart';
import 'package:iconstruct/features/auth/presentation/screens/saved_projects.dart';
import 'package:iconstruct/features/bidding/screens/posted_project_details_screen.dart';
import 'package:iconstruct/features/project_creation/data/project_lifecycle.dart';

/// Hammer / Bidding tab. Opens the latest posted estimate display, or a
/// prompt to create one — not a new material plan.
class BiddingHubScreen extends StatefulWidget {
  const BiddingHubScreen({super.key});

  static const Color _cream = Color(0xFFEDE4D4);
  static const Color _navy = Color(0xFF2C3E50);
  static const Color _midBlue = Color(0xFF648DB6);

  @override
  State<BiddingHubScreen> createState() => _BiddingHubScreenState();
}

class _BiddingHubScreenState extends State<BiddingHubScreen> {
  static const Color _cream = BiddingHubScreen._cream;

  // Resolved once — the lookup forces an ID-token refresh and a query, so it
  // must not re-run on every rebuild.
  late final Future<String?> _postIdFuture = _latestPostedPostId();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _postIdFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _BiddingScaffold(
            child: Center(child: CircularProgressIndicator(color: _cream)),
          );
        }

        if (snapshot.hasError) {
          return _BiddingScaffold(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  firestoreUserMessage(
                    snapshot.error!,
                    action: 'load your posted estimate',
                  ),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    color: _cream,
                    height: 1.4,
                  ),
                ),
              ),
            ),
          );
        }

        final postId = snapshot.data;
        if (postId != null && postId.isNotEmpty) {
          return PostedProjectDetailsScreen(postId: postId);
        }

        return const _BiddingEmptyView();
      },
    );
  }

  static Future<String?> _latestPostedPostId() async {
    final active = ActiveProjectState.instance.activeProject;
    final activePostId = active?.postId;
    if (active != null &&
        activePostId != null &&
        activePostId.isNotEmpty &&
        ProjectLifecycle.isPosted(active.status, postId: activePostId)) {
      return activePostId;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    try {
      await user.getIdToken(true);
    } catch (_) {}

    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('saved_projects')
        .orderBy('updatedAt', descending: true)
        .limit(20)
        .get();

    for (final doc in snap.docs) {
      final project = ProjectModel.fromDocument(doc);
      final postId = project.postId;
      if (postId != null &&
          postId.isNotEmpty &&
          ProjectLifecycle.isPosted(project.status, postId: postId)) {
        return postId;
      }
    }
    return null;
  }
}

class _BiddingScaffold extends StatelessWidget {
  final Widget child;

  const _BiddingScaffold({required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BiddingHubScreen._midBlue,
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [BiddingHubScreen._navy, BiddingHubScreen._midBlue],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          child,
          const OffsetPillNav(activeTab: OffsetNavTab.bidding),
        ],
      ),
    );
  }
}

class _BiddingEmptyView extends StatelessWidget {
  const _BiddingEmptyView();

  @override
  Widget build(BuildContext context) {
    return _BiddingScaffold(
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: MediaQuery.sizeOf(context).height * 0.45,
            child: Container(
              decoration: const BoxDecoration(
                color: BiddingHubScreen._cream,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(60),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Stack(
              children: [
                Positioned(
                  top: 10,
                  left: 20,
                  child: Material(
                    color: BiddingHubScreen._navy,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => Navigator.pop(context),
                      child: const SizedBox(
                        width: 44,
                        height: 44,
                        child: Icon(
                          Icons.arrow_back_ios_new,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 90,
                  right: 0,
                  left: IConstructPanel.leftInsetOf(context),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(28, 36, 24, 30),
                    decoration: const BoxDecoration(
                      color: BiddingHubScreen._navy,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(55),
                        bottomLeft: Radius.circular(55),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 15,
                          offset: Offset(-5, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Canvass shops',
                          style: GoogleFonts.poppins(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Divider(color: Colors.white30, thickness: 1),
                        const SizedBox(height: 20),
                        Text(
                          'Create a project display',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            color: BiddingHubScreen._cream,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Post a finished material estimate so hardware shops can send quotations. This tab shows that display — it does not start a new plan.',
                          style: GoogleFonts.poppins(
                            color: const Color(0xFFE0D7C9),
                            fontSize: 14,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 28),
                        Align(
                          alignment: Alignment.centerRight,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: BiddingHubScreen._cream,
                              foregroundColor: BiddingHubScreen._navy,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 10,
                              ),
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const SavedProjectsScreen(
                                    focus: SavedProjectsFocus.readyToPost,
                                  ),
                                ),
                              );
                            },
                            child: Text(
                              'Create a project display',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () =>
                                PlanningNav.startNewEstimate(context),
                            child: Text(
                              'Start a new estimate',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: BiddingHubScreen._cream,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
