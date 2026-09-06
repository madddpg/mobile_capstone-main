import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:iconstruct/core/firebase/firestore_error.dart';
import 'package:iconstruct/core/state/onboarding_preferences.dart';
import 'package:iconstruct/core/theme/app_theme.dart';
import 'package:iconstruct/core/widgets/iconstruct_panel.dart';
import 'package:iconstruct/core/widgets/offset_panel_shell.dart';
import 'package:iconstruct/core/widgets/app_message.dart';
import 'package:iconstruct/features/chat/data/chat_service.dart';
import 'package:iconstruct/features/chat/widgets/message_list.dart';
import 'package:iconstruct/features/onboarding/data/home_guide_steps.dart';
import 'package:iconstruct/features/onboarding/presentation/widgets/home_guide_overlay.dart';

class ChatThreadScreen extends StatefulWidget {
  final String conversationId;
  final String? shopName;
  final String? postId;
  final String? shopId;
  final String? quotationId;
  final String? projectTitle;
  final bool forceChatGuide;

  const ChatThreadScreen({
    super.key,
    required this.conversationId,
    this.shopName,
    this.postId,
    this.shopId,
    this.quotationId,
    this.projectTitle,
    this.forceChatGuide = false,
  });

  @override
  State<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends State<ChatThreadScreen> {
  final _chat = ChatService();
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  bool _sending = false;
  bool _guideVisible = false;
  int _guideStep = 0;
  bool _preparing = true;
  String? _prepareError;

  /// Newest message id already marked read, so repeated rebuilds of the
  /// message list do not each write a read marker.
  String? _markedReadUpTo;
  final List<HomeGuideStep> _guideSteps = chatGuideSteps();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _prepareThread();
      // Opening the thread is what clears its badge.
      await _chat.markConversationRead(widget.conversationId);
      if (mounted) await _maybeStartGuide();
    });
  }

  Future<void> _prepareThread() async {
    final postId = widget.postId?.trim() ?? '';
    final shopId = widget.shopId?.trim() ?? '';
    if (postId.isEmpty || shopId.isEmpty) {
      if (mounted) setState(() => _preparing = false);
      return;
    }
    try {
      await _chat.ensureConversationAfterAccept(
        projectId: postId,
        shopId: shopId,
        quotationId: widget.quotationId ?? shopId,
        projectTitle: widget.projectTitle ?? widget.shopName ?? 'Estimate',
        shopName: widget.shopName ?? '',
      );
      if (mounted) setState(() => _preparing = false);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _preparing = false;
        _prepareError = firestoreUserMessage(
          error,
          action: 'load this conversation',
        );
      });
    }
  }

  Future<void> _maybeStartGuide() async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (!widget.forceChatGuide &&
        await OnboardingPreferences.hasSeenChatGuide(uid)) {
      return;
    }
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
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text;
    if (text.trim().isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await _chat.sendMessage(
        conversationId: widget.conversationId,
        text: text,
      );
      _controller.clear();
      if (_scroll.hasClients) {
        await _scroll.animateTo(
          _scroll.position.maxScrollExtent + 80,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      if (!mounted) return;
      showAppMessage(
        context,
        SnackBar(
          content: Text(firestoreUserMessage(e, action: 'send this message')),
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
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
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _chat.watchConversation(widget.conversationId),
        builder: (context, convSnap) {
          final data = convSnap.data?.data();
          final shopName =
              widget.shopName ?? (data?['shopName'] ?? 'Hardware shop').toString();
          final title = (data?['projectTitle'] ?? '').toString();
          final closed = (data?['status'] ?? 'open').toString() == 'closed';

          return Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  shopName,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    color: AppColors.cream,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                  ),
                ),
              ),
              if (title.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      color: AppColors.cream.withValues(alpha: 0.7),
                      fontSize: 12.5,
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  height: 1,
                  color: AppColors.cream.withValues(alpha: 0.35),
                ),
              ),
              Expanded(
                child: _preparing
                    ? const Center(
                        child: CircularProgressIndicator(color: AppColors.cream),
                      )
                    : _prepareError != null
                    ? Padding(
                        padding: const EdgeInsets.all(28),
                        child: Text(
                          _prepareError!,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            color: AppColors.cream.withValues(alpha: 0.85),
                          ),
                        ),
                      )
                    : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _chat.watchMessages(widget.conversationId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting &&
                        !snapshot.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(color: AppColors.cream),
                      );
                    }
                    if (snapshot.hasError) {
                      return Padding(
                        padding: const EdgeInsets.all(28),
                        child: Text(
                          firestoreUserMessage(
                            snapshot.error!,
                            action: 'load this conversation',
                          ),
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            color: AppColors.cream.withValues(alpha: 0.85),
                          ),
                        ),
                      );
                    }

                    // watchMessages returns newest-first; reverse for display.
                    final raw = snapshot.data?.docs ?? [];

                    // A message arriving while the thread is open is already
                    // being read, so clear its badge rather than leaving a
                    // count for something on screen.
                    if (raw.isNotEmpty && raw.first.id != _markedReadUpTo) {
                      _markedReadUpTo = raw.first.id;
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _chat.markConversationRead(widget.conversationId);
                      });
                    }

                    final docs = raw.reversed.toList();
                    if (docs.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.all(28),
                        child: Text(
                          'Quote accepted — you can now message this shop about materials and pickup.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            color: AppColors.cream.withValues(alpha: 0.8),
                            height: 1.4,
                          ),
                        ),
                      );
                    }

                    return MessengerMessageList(
                      docs: docs.map((d) => d.data()).toList(),
                      uid: uid,
                      shopName: shopName,
                      conversation: data,
                      controller: _scroll,
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: closed
                    ? Text(
                        'This thread is closed.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          color: AppColors.cream.withValues(alpha: 0.7),
                        ),
                      )
                    : _preparing || _prepareError != null
                    ? const SizedBox.shrink()
                    : Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _controller,
                              minLines: 1,
                              maxLines: 4,
                              style: GoogleFonts.poppins(
                                color: AppColors.textDark,
                                fontSize: 14,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Message this shop…',
                                hintStyle: GoogleFonts.poppins(
                                  color: AppColors.textMuted,
                                  fontSize: 13,
                                ),
                                filled: true,
                                fillColor: AppColors.cream,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(22),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              textInputAction: TextInputAction.send,
                              onSubmitted: (_) => _send(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Material(
                            color: AppColors.cream,
                            shape: const CircleBorder(),
                            child: IconButton(
                              onPressed: _sending ? null : _send,
                              icon: _sending
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.send_rounded,
                                      color: AppColors.navySoft,
                                    ),
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          );
        },
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
