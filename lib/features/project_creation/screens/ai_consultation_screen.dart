import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_functions/cloud_functions.dart';

import 'package:iconstruct/core/widgets/iconstruct_panel.dart';
import 'package:iconstruct/core/widgets/offset_panel_shell.dart';
import 'package:iconstruct/core/widgets/user_avatar.dart';
import 'package:iconstruct/features/auth/presentation/screens/profile_screen.dart';
import 'package:iconstruct/features/project_creation/data/ai_material_consultant_service.dart';
import 'package:iconstruct/features/project_creation/data/bom_quantity_estimator.dart';
import 'package:iconstruct/features/project_creation/data/description_hints.dart';
import 'package:iconstruct/features/project_creation/data/renovation_scope.dart';
import 'package:iconstruct/features/project_creation/screens/template_area_screen.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  const ChatMessage({required this.text, required this.isUser});
}

/// AI-first material consultation. Template packages are a separate planning path.
class AIConsultationScreen extends StatefulWidget {
  final String projectName;
  final String? customProjectName;
  final String? projectNotes;

  /// Chosen on the renovation type step. The chat no longer asks for it.
  final RenovationScope scope;

  /// Materials the builder already kept, when they came here from the AI's
  /// recommendations. The chat continues that list rather than starting an
  /// empty one, so describing the job once is enough.
  final List<String> initialMaterials;

  const AIConsultationScreen({
    super.key,
    required this.projectName,
    this.customProjectName,
    this.projectNotes,
    this.scope = RenovationScope.cosmetic,
    this.initialMaterials = const [],
  });

  @override
  State<AIConsultationScreen> createState() => _AIConsultationScreenState();
}

class _AIConsultationScreenState extends State<AIConsultationScreen> {
  final List<ChatMessage> _messages = [];
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final _aiService = AiMaterialConsultantService();

  bool _isTyping = false;
  int _step = _stepChat;
  String _style = '';
  String _budget = '';
  final List<String> _ideaLog = [];
  final List<String> _confirmedMaterials = [];

  /// Free chat → optional suggestion chips → budget → measure → BOM. The
  /// renovation type and the room's size have their own screens, so the chat
  /// no longer asks for either.
  static const int _stepChat = 0;
  static const int _stepBudget = 1;
  static const int _stepDone = 2;

  List<String> _pendingRecommendations = [];
  final Set<String> _pendingSelected = {};
  bool _showBomChip = true;

  static const Color _cream = Color(0xFFEDE4D4);
  static const Color _darkBlue = Color(0xFF2C3E50);
  static const Color _navy = Color(0xFF1E3042);

  @override
  void initState() {
    super.initState();
    for (final name in widget.initialMaterials) {
      final trimmed = name.trim();
      if (trimmed.isEmpty) continue;
      final isNew = !_confirmedMaterials
          .any((m) => m.toLowerCase() == trimmed.toLowerCase());
      if (isNew) _confirmedMaterials.add(trimmed);
    }
    _startConversation();
  }

  void _startConversation() async {
    await _addBotMessage(
      "Hi! I'm the iConstruct AI Material Consultant for ${widget.projectName}.",
    );
    await Future.delayed(const Duration(milliseconds: 350));
    await _addBotMessage(
      "This is a ${widget.scope.label.toLowerCase()} renovation: "
      "${widget.scope.description.toLowerCase()}. Tell me what you want done "
      "and I'll suggest materials. When you're ready, tap Build my BOM. "
      "You'll measure the room next so the quantities fit it.",
    );

    // Arriving from the AI's recommendations with a list already ticked: say
    // so, or the builder cannot tell whether those materials survived the
    // move and starts describing the job a second time.
    if (_confirmedMaterials.isNotEmpty) {
      final count = _confirmedMaterials.length;
      await Future.delayed(const Duration(milliseconds: 350));
      await _addBotMessage(
        "I've kept the $count material${count == 1 ? '' : 's'} you ticked, so "
        "your list is not empty. Tell me what else you need and I'll suggest "
        "options to add to it.",
      );
    }
  }

  bool _isReadyToBuild(String text) {
    final t = text.toLowerCase().trim();
    return t == 'ready' ||
        t == 'done' ||
        t == 'finish' ||
        t.contains('build my') ||
        t.contains('bill of material') ||
        t.contains("i'm ready") ||
        t.contains('im ready') ||
        t.contains('generate bom') ||
        t.contains("that's all") ||
        t.contains('thats all');
  }

  void _captureStyleHints(String input) {
    final t = input.toLowerCase();
    if (_style.isNotEmpty) return;
    if (t.contains('modern')) {
      _style = 'Modern';
    } else if (t.contains('minimal')) {
      _style = 'Minimalist';
    } else if (t.contains('traditional') || t.contains('classic')) {
      _style = 'Traditional';
    } else if (input.trim().length <= 40 &&
        !RegExp(r'^\d').hasMatch(input.trim())) {
      _style = input.trim();
    }
  }

  Future<void> _beginBudgetThenGenerate() async {
    if (_confirmedMaterials.isEmpty) {
      await _addBotMessage(
        "You haven't added any materials to your list yet. "
        "Describe what you want and pick optional suggestions. "
        "I won't decide the BOM for you.",
      );
      setState(() {
        _step = _stepChat;
        _showBomChip = true;
      });
      return;
    }

    setState(() {
      _showBomChip = false;
      _pendingRecommendations = [];
      _pendingSelected.clear();
      _step = _stepBudget;
    });
    await _addBotMessage(
      "Before I draft your Bill of Materials from what you chose: "
      "Low, Medium, or High budget for material quality? (Guides tier only — not a fixed price.)",
    );
  }

  void _handleSubmitted(String text) async {
    if (text.trim().isEmpty || _step >= _stepDone) return;

    final input = text.trim();
    _textController.clear();
    setState(() {
      _messages.add(ChatMessage(text: input, isUser: true));
    });
    _scrollToBottom();

    switch (_step) {
      case _stepChat:
        await _handleFreeChat(input);
        break;

      case _stepBudget:
        _budget = input;
        _step = _stepDone;
        await _addBotMessage(
          "Thanks! Drafting a Bill of Materials from your ideas"
          "… Next, measure the room so the quantities fit it.",
        );
        _generateBOM();
        break;
    }
  }

  Future<void> _handleFreeChat(String input) async {
    if (_isReadyToBuild(input)) {
      await _beginBudgetThenGenerate();
      return;
    }

    _ideaLog.add(input);
    _captureStyleHints(input);

    setState(() {
      _isTyping = true;
      _pendingRecommendations = [];
      _pendingSelected.clear();
      _showBomChip = true;
    });

    final result = await _aiService.consult(
      projectType: widget.projectName,
      userMessage: input,
      style: _style,
      scope: widget.scope.label,
      ideaLog: List<String>.from(_ideaLog),
      selectedMaterials: List<String>.from(_confirmedMaterials),
      projectNotes: widget.projectNotes,
    );

    if (!mounted) return;
    setState(() => _isTyping = false);

    if (!result.success) {
      final reason = (result.errorMessage ?? '').trim();
      await _addBotMessage(
        "${reason.isEmpty ? 'iConstruct AI is unavailable right now.' : reason} "
        "You can still list the materials you want here, then tap "
        "“Build my BOM” to continue — quantities are estimated for you.",
      );
      return;
    }

    final reply = result.reply.isNotEmpty
        ? result.reply
        : (result.inScope
            ? "Tell me more about the materials you want — I only suggest; you decide."
            : "I can only help with iConstruct material planning for this estimate.");

    setState(() {
      _messages.add(ChatMessage(text: reply, isUser: false));
    });
    _scrollToBottom();

    if (!result.inScope || result.suggestions.isEmpty) {
      setState(() {
        _pendingRecommendations = [];
        _pendingSelected.clear();
        _showBomChip = true;
      });
      return;
    }

    _pendingRecommendations = List<String>.from(result.suggestions);
    _pendingSelected.clear();
    setState(() => _showBomChip = true);
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;
    await _openSuggestionsModal();
  }

  Future<void> _openSuggestionsModal() async {
    if (!mounted || _pendingRecommendations.isEmpty) return;

    final selected = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final working = Set<String>.from(_pendingSelected);
        return StatefulBuilder(
          builder: (context, setModalState) {
            final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
            return Padding(
              padding: EdgeInsets.only(bottom: bottomInset),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.72,
                ),
                decoration: const BoxDecoration(
                  color: Color(0xFF1E3042),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 10),
                    Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: _cream.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(22, 18, 14, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Suggested materials',
                                  style: GoogleFonts.poppins(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: _cream,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Optional picks — nothing is added until you choose.',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: _cream.withValues(alpha: 0.75),
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(ctx),
                            icon: Icon(
                              Icons.close_rounded,
                              color: _cream.withValues(alpha: 0.85),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(color: Color(0x33EDE4D4), height: 1),
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                        child: Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: _pendingRecommendations.map((name) {
                            final isOn = working.contains(name);
                            return FilterChip(
                              selected: isOn,
                              showCheckmark: true,
                              checkmarkColor: _darkBlue,
                              label: Text(
                                name,
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isOn ? _darkBlue : _cream,
                                ),
                              ),
                              selectedColor: _cream,
                              backgroundColor: _navy,
                              side: BorderSide(
                                color: _cream.withValues(alpha: 0.7),
                              ),
                              onSelected: (value) {
                                setModalState(() {
                                  if (value) {
                                    working.add(name);
                                  } else {
                                    working.remove(name);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                      child: Row(
                        children: [
                          Expanded(
                            child: _ChoiceChipButton(
                              label: 'Skip',
                              onTap: () => Navigator.pop(ctx, <String>{}),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _ChoiceChipButton(
                              label: working.isEmpty
                                  ? 'Add to my list'
                                  : 'Add (${working.length})',
                              filled: true,
                              onTap: () =>
                                  Navigator.pop(ctx, Set<String>.from(working)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (!mounted) return;

    // Dismissed without action — keep a reopen button via pending list
    if (selected == null) {
      setState(() {});
      return;
    }

    if (selected.isEmpty) {
      await _skipSuggestions();
      return;
    }

    _pendingSelected
      ..clear()
      ..addAll(selected);
    await _confirmPendingSelection();
  }

  Future<void> _confirmPendingSelection() async {
    if (_pendingSelected.isEmpty) {
      await _addBotMessage(
        "No materials selected — that's fine. Keep describing your idea, or open suggestions again to pick some.",
      );
      return;
    }

    for (final m in _pendingSelected) {
      if (!_confirmedMaterials.contains(m)) _confirmedMaterials.add(m);
    }

    final picked = _pendingSelected.toList();
    setState(() {
      _messages.add(
        ChatMessage(
          text: 'I want to include: ${picked.join(', ')}',
          isUser: true,
        ),
      );
      _pendingRecommendations = [];
      _pendingSelected.clear();
      _showBomChip = true;
      _step = _stepChat;
    });
    _scrollToBottom();

    await _addBotMessage(
      "Added ${picked.length} material(s) to your list "
      "(${_confirmedMaterials.length} total so far). "
      "Tap the list icon anytime to see or remove what you chose. "
      "Share more ideas, or Build my BOM when you're satisfied.",
    );
  }

  Future<void> _openConfirmedMaterialsSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            void removeAt(int index) {
              setState(() => _confirmedMaterials.removeAt(index));
              setModalState(() {});
            }

            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.72,
              ),
              decoration: const BoxDecoration(
                color: Color(0xFF1E3042),
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: _cream.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 18, 14, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Your material list',
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: _cream,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _confirmedMaterials.isEmpty
                                    ? 'Nothing here yet. Describe what you want, then pick from suggestions — I will not add materials for you.'
                                    : 'These are the materials you chose. Remove anything you do not want on the estimate.',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: _cream.withValues(alpha: 0.75),
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: Icon(
                            Icons.close_rounded,
                            color: _cream.withValues(alpha: 0.85),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(color: Color(0x33EDE4D4), height: 1),
                  if (_confirmedMaterials.isEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(22, 28, 22, 32),
                      child: Text(
                        'Your list is empty.',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: _cream.withValues(alpha: 0.7),
                        ),
                      ),
                    )
                  else
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.fromLTRB(12, 8, 8, 12),
                        itemCount: _confirmedMaterials.length,
                        separatorBuilder: (_, _) => const Divider(
                          color: Color(0x22EDE4D4),
                          height: 1,
                        ),
                        itemBuilder: (context, index) {
                          final name = _confirmedMaterials[index];
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10,
                            ),
                            title: Text(
                              name,
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: _cream,
                              ),
                            ),
                            trailing: IconButton(
                              tooltip: 'Remove from list',
                              onPressed: () => removeAt(index),
                              icon: Icon(
                                Icons.close_rounded,
                                color: _cream.withValues(alpha: 0.8),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                    child: SizedBox(
                      width: double.infinity,
                      child: _ChoiceChipButton(
                        label: _confirmedMaterials.isEmpty
                            ? 'Close'
                            : 'Done · ${_confirmedMaterials.length} selected',
                        filled: true,
                        onTap: () => Navigator.pop(ctx),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    if (mounted) setState(() {});
  }

  Future<void> _skipSuggestions() async {
    setState(() {
      _messages.add(
        const ChatMessage(text: 'Skip suggestions — keep chatting', isUser: true),
      );
      _pendingRecommendations = [];
      _pendingSelected.clear();
      _showBomChip = true;
      _step = _stepChat;
    });
    _scrollToBottom();
    await _addBotMessage(
      "No problem — your call. Tell me more about what you want for this project.",
    );
  }

  Future<void> _onChipReady() async {
    setState(() {
      _messages.add(const ChatMessage(text: "I'm ready — build my BOM", isUser: true));
      _showBomChip = false;
    });
    _scrollToBottom();
    await _beginBudgetThenGenerate();
  }

  Future<void> _addBotMessage(String text) async {
    setState(() => _isTyping = true);
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    setState(() {
      _isTyping = false;
      _messages.add(ChatMessage(text: text, isUser: false));
    });
    _scrollToBottom();
  }

  Future<void> _generateBOM() async {
    final selected = List<String>.from(_confirmedMaterials);

    // The builder leads the plan: what they picked is what they review.
    if (selected.isNotEmpty) {
      await _addBotMessage(
        "Building your BOM with the ${selected.length} material"
        "${selected.length == 1 ? '' : 's'} you selected.",
      );
      _openBomFromSelections(selected);
      return;
    }

    setState(() => _isTyping = true);

    try {
      final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('generateAIBOM');
      final response = await callable.call(<String, dynamic>{
        'projectType': widget.projectName,
        'style': _style.isEmpty ? 'As described by user' : _style,
        'areaSqm': 0,
        'scope': widget.scope.label,
        'budgetLevel': _budget,
        'additionalNotes': [
          'Renovation type: ${widget.scope.label} — ${widget.scope.description}.',
          'The user picked no materials from suggestions — draft only the '
              'essentials implied by the ideas below.',
          'Do not invent a full sequential package beyond those essentials.',
          if (_ideaLog.isNotEmpty) 'User ideas (in their words):',
          ..._ideaLog.map((e) => '- $e'),
          if (widget.projectNotes != null &&
              widget.projectNotes!.trim().isNotEmpty)
            'Estimate notes: ${widget.projectNotes!.trim()}',
        ].join('\n'),
      });

      final data = response.data;
      if (data != null && data['success'] == true) {
        final List<dynamic> materialsRaw = data['materials'] ?? [];
        final names = materialsRaw
            .map((m) => (m['name'] ?? '').toString())
            .where((n) => n.trim().isNotEmpty)
            .toList();

        setState(() => _isTyping = false);
        if (!mounted) return;

        if (names.isNotEmpty) {
          _openBomReview(names);
        } else {
          _openBomFromSelections(selected);
        }
        return;
      }

      setState(() => _isTyping = false);
      await _addBotMessage(
        "Cloud AI didn't return a list — building your BOM from materials you selected.",
      );
      _openBomFromSelections(selected);
    } catch (e) {
      setState(() => _isTyping = false);
      await _addBotMessage(
        "AI service unavailable — building your essential BOM locally from what you selected.",
      );
      _openBomFromSelections(selected);
    }
  }

  /// Builds the review BOM from exactly the materials the builder confirmed.
  void _openBomFromSelections(List<String> selected) {
    final names = selected.isNotEmpty ? selected : _confirmedMaterials;
    if (names.isEmpty) {
      setState(() {
        _step = _stepChat;
        _showBomChip = true;
        _isTyping = false;
      });
      _addBotMessage(
        "I couldn't draft a BOM without your picks. Add materials from suggestions first.",
      );
      return;
    }
    _openBomReview(names);
  }

  /// Opens the measuring step with exactly the materials the builder chose.
  void _openBomReview(List<String> materialNames) {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => TemplateAreaScreen(
          template: BomQuantityEstimator.consultationTemplate(
            projectType: widget.projectName,
            materialNames: materialNames,
            scope: widget.scope,
          ),
          projectName: widget.projectName,
          customProjectName: widget.customProjectName,
          projectNotes: widget.projectNotes,
          scope: widget.scope,
          budgetPreference: _budget,
          hints: parseSiteHints(widget.projectNotes ?? ''),
        ),
      ),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pad = IConstructPanel.contentPaddingOf(context);

    return OffsetPanelShell(
      extent: OffsetPanelExtent.fillBottom,
      panelColor: IConstructPanel.navy,
      borderRadius: IConstructPanel.offsetTallRadiusOf(context),
      contentPadding: EdgeInsets.zero,
      header: _buildTopBar(),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(pad.left, pad.top, pad.right, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        'AI Material\nConsultant',
                        style: GoogleFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          height: 1.15,
                        ),
                      ),
                    ),
                    _MaterialsListButton(
                      count: _confirmedMaterials.length,
                      onTap: _openConfirmedMaterialsSheet,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  widget.customProjectName?.isNotEmpty == true
                      ? widget.customProjectName!
                      : widget.projectName,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: _cream.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Powered by AI API · iConstruct material planning only. You choose; I suggest.',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: const Color(0xFFE0D7C9),
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 12),
                const Divider(color: _cream, thickness: 1),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: EdgeInsets.fromLTRB(pad.left, 12, pad.right, 12),
              itemCount: _messages.length + (_isTyping ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length) {
                  return _buildTypingIndicator();
                }
                return _buildMessageBubble(_messages[index]);
              },
            ),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Material(
            color: _darkBlue,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => Navigator.pop(context),
              child: const SizedBox(
                width: 40,
                height: 40,
                child: Icon(Icons.arrow_back_rounded, color: _cream, size: 22),
              ),
            ),
          ),
          const Spacer(),
          UserAvatar(
            size: 34,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final isUser = message.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        decoration: BoxDecoration(
          color: isUser ? const Color(0xFF648DB6) : _cream,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isUser ? 18 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 18),
          ),
        ),
        child: Text(
          message.text,
          style: GoogleFonts.poppins(
            color: isUser ? Colors.white : _darkBlue,
            fontSize: 13,
            height: 1.35,
          ),
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: _cream,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          'AI is thinking…',
          style: GoogleFonts.poppins(color: _darkBlue, fontSize: 12),
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    final canSend = _step < _stepDone;

    final pad = IConstructPanel.contentPaddingOf(context);

    return Container(
      padding: EdgeInsets.fromLTRB(pad.left, 10, pad.right, 12),
      decoration: BoxDecoration(
        color: _darkBlue.withValues(alpha: 0.55),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_pendingRecommendations.isNotEmpty) ...[
            SizedBox(
              width: double.infinity,
              child: _ChoiceChipButton(
                label: 'Review suggestions (${_pendingRecommendations.length})',
                onTap: _openSuggestionsModal,
              ),
            ),
            const SizedBox(height: 10),
          ],
          if (_showBomChip && _step == _stepChat) ...[
            SizedBox(
              width: double.infinity,
              child: _ChoiceChipButton(
                label: _confirmedMaterials.isEmpty
                    ? 'Build my BOM'
                    : 'Build my BOM (${_confirmedMaterials.length})',
                filled: true,
                onTap: _onChipReady,
              ),
            ),
            const SizedBox(height: 10),
          ],
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _textController,
                  style: const TextStyle(color: Colors.white),
                  scrollPadding: const EdgeInsets.only(bottom: 80),
                  decoration: InputDecoration(
                    hintText: 'Describe your project ideas freely…',
                    hintStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: _navy,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 10,
                    ),
                  ),
                  onSubmitted: canSend ? _handleSubmitted : null,
                ),
              ),
              const SizedBox(width: 10),
              CircleAvatar(
                backgroundColor: _cream,
                child: IconButton(
                  icon: const Icon(
                    Icons.send_rounded,
                    color: _darkBlue,
                    size: 20,
                  ),
                  onPressed: canSend
                      ? () => _handleSubmitted(_textController.text)
                      : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MaterialsListButton extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const _MaterialsListButton({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: count == 0
          ? 'Your material list, empty'
          : 'Your material list, $count selected',
      child: Material(
        color: const Color(0xFFEDE4D4),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                const Icon(
                  Icons.list_alt_rounded,
                  color: Color(0xFF2C3E50),
                  size: 22,
                ),
                if (count > 0)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Container(
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: const BoxDecoration(
                        color: Color(0xFF2C3E50),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        count > 9 ? '9+' : '$count',
                        style: GoogleFonts.poppins(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFEDE4D4),
                          height: 1,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChoiceChipButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool filled;

  const _ChoiceChipButton({
    required this.label,
    required this.onTap,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: filled ? const Color(0xFFEDE4D4) : Colors.transparent,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFEDE4D4)),
          ),
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: filled
                  ? const Color(0xFF2C3E50)
                  : const Color(0xFFEDE4D4),
            ),
          ),
        ),
      ),
    );
  }
}
