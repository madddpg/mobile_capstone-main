import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:iconstruct/core/firebase/firestore_error.dart';
import 'package:iconstruct/core/state/onboarding_preferences.dart';
import 'package:iconstruct/core/theme/app_theme.dart';
import 'package:iconstruct/core/widgets/iconstruct_panel.dart';
import 'package:iconstruct/core/widgets/offset_panel_shell.dart';
import 'package:iconstruct/features/chat/data/chat_service.dart';
import 'package:iconstruct/features/chat/screens/chat_thread_screen.dart';
import 'package:iconstruct/features/onboarding/data/home_guide_steps.dart';
import 'package:iconstruct/features/onboarding/presentation/widgets/home_guide_overlay.dart';

class ChatInboxScreen extends StatefulWidget {
  final bool forceChatGuide;

  const ChatInboxScreen({super.key, this.forceChatGuide = false});

  @override
  State<ChatInboxScreen> createState() => _ChatInboxScreenState();
}

class _ChatInboxScreenState extends State<ChatInboxScreen> {
  bool _guideVisible = false;
  int _guideStep = 0;
  final List<HomeGuideStep> _guideSteps = chatGuideSteps();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeStartGuide());
  }

  Future<void> _maybeStartGuide() async {
    if (!widget.forceChatGuide) return;
    if (!mounted) return;
    setState(() {
      _guideVisible = true;
      _guideStep = 0;
    });
  }

  Future<void> _finishGuide() async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    await OnboardingPreferences.markChatGuideSeen(uid);
    if (!mounted) return;
    setState(() => _guideVisible = false);
  }

  Future<void> _nextGuideStep() async {
    if (_guideStep >= _guideSteps.length - 1) {
      await _finishGuide();
      return;
    }
    setState(() => _guideStep += 1);
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Stack(
      children: [
        OffsetPanelShell(
          extent: OffsetPanelExtent.centeredWithNav,
          safeAreaBottom: false,
          activeNav: OffsetNavTab.chat,
          panelColor: IConstructPanel.darkBlue,
          contentPadding: EdgeInsets.zero,
          header: OffsetPanelHeaders.backOnly(context),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'Shop messages',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    color: AppColors.cream,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'Opens after you select a supplier.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    color: AppColors.cream.withValues(alpha: 0.72),
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  height: 1,
                  color: AppColors.cream.withValues(alpha: 0.35),
                ),
              ),
              Expanded(
                child: uid == null
                    ? Center(
                        child: Text(
                          'Sign in to see shop messages.',
                          style: GoogleFonts.poppins(color: AppColors.cream),
                        ),
                      )
                    : StreamBuilder<
                        List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
                        stream: ChatService().watchMyConversations(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(
                                color: AppColors.cream,
                              ),
                            );
                          }
                          if (snapshot.hasError) {
                            return Padding(
                              padding: const EdgeInsets.all(28),
                              child: Text(
                                firestoreUserMessage(
                                  snapshot.error!,
                                  action: 'load shop messages',
                                ),
                                textAlign: TextAlign.center,
                                style: GoogleFonts.poppins(
                                  color: AppColors.cream.withValues(alpha: 0.85),
                                  height: 1.4,
                                ),
                              ),
                            );
                          }

                          final docs = snapshot.data ?? const [];
                          if (docs.isEmpty) {
                            return Padding(
                              padding: const EdgeInsets.all(32),
                              child: Text(
                                'No shop threads yet. Select a supplier on a posted estimate to start messaging.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.poppins(
                                  color: AppColors.cream.withValues(alpha: 0.8),
                                  height: 1.4,
                                ),
                              ),
                            );
                          }

                          return ListView.separated(
                            padding: const EdgeInsets.fromLTRB(20, 16, 18, 28),
                            itemCount: docs.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final doc = docs[index];
                              final data = doc.data();
                              final shopName = (data['shopName'] ??
                                      'Hardware shop')
                                  .toString();
                              final title =
                                  (data['projectTitle'] ?? 'Estimate')
                                      .toString();
                              final last = (data['lastMessage'] ?? '').toString();
                              return Material(
                                color: AppColors.cream,
                                borderRadius: BorderRadius.circular(22),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(22),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ChatThreadScreen(
                                          conversationId: doc.id,
                                        ),
                                      ),
                                    );
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      18,
                                      16,
                                      18,
                                      16,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          shopName,
                                          style: GoogleFonts.poppins(
                                            color: AppColors.textDark,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 16,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          title,
                                          style: GoogleFonts.poppins(
                                            color: AppColors.textMuted,
                                            fontSize: 12,
                                          ),
                                        ),
                                        if (last.isNotEmpty) ...[
                                          const SizedBox(height: 8),
                                          Text(
                                            last,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.poppins(
                                              color: AppColors.textDark,
                                              fontSize: 13,
                                              height: 1.35,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
        if (_guideVisible)
          Positioned.fill(
            child: HomeGuideOverlay(
              steps: _guideSteps,
              stepIndex: _guideStep,
              highlight: null,
              onNext: _nextGuideStep,
              onSkip: _finishGuide,
            ),
          ),
      ],
    );
  }
}
