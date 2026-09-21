import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:iconstruct/core/widgets/iconstruct_panel.dart';
import 'package:iconstruct/core/widgets/offset_panel_shell.dart';
import 'package:iconstruct/core/widgets/user_avatar.dart';
import 'package:iconstruct/features/auth/presentation/screens/profile_screen.dart';
import 'package:iconstruct/features/project_creation/data/ai_material_consultant_service.dart';
import 'package:iconstruct/features/project_creation/data/description_hints.dart';
import 'package:iconstruct/features/project_creation/data/renovation_coverage.dart';
import 'package:iconstruct/features/project_creation/data/renovation_scope.dart';
import 'package:iconstruct/features/project_creation/data/renovation_templates.dart';
import 'package:iconstruct/features/project_creation/screens/select_work_items_screen.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  const ChatMessage({required this.text, required this.isUser});
}

/// AI chat about the job. The AI suggests work from the project's checklist,
/// never materials, and the builder's picks open that checklist ticked, so a
/// chatted estimate is built from the same work items and formulas as any
/// other.
class AIConsultationScreen extends StatefulWidget {
  final String projectName;
  final String? customProjectName;
  final String? projectNotes;

  /// Chosen on the renovation type step. The chat no longer asks for it.
  final RenovationScope scope;

  /// How much of the space the job covers. Its own dimension: a partial
  /// cosmetic job and a full one are the same kind of work over different
  /// amounts of room.
  final RenovationCoverage coverage;

  /// Every kind of work chosen, of which [scope] is the heaviest. Null from a
  /// caller that predates multi-select, which then means [scope] alone.
  final RenovationTypes? renovationTypes;

  RenovationTypes get types => renovationTypes ?? RenovationTypes.only(scope);

  const AIConsultationScreen({
    super.key,
    required this.projectName,
    this.customProjectName,
    this.projectNotes,
    this.scope = RenovationScope.cosmetic,
    this.coverage = RenovationCoverage.full,
    this.renovationTypes,
  });

  @override
  State<AIConsultationScreen> createState() => _AIConsultationScreenState();
}

class _AIConsultationScreenState extends State<AIConsultationScreen> {
  final List<ChatMessage> _messages = [];
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final _aiService = AiMaterialConsultantService();

  late final WorkCatalogue _catalogue =
      RenovationTemplatesCatalog.workCatalogueFor(widget.projectName);

  bool _isTyping = false;
  int _step = _stepChat;
  String _style = '';
  String _budget = '';
  final List<String> _ideaLog = [];

  /// Work item ids the builder added from the AI's suggestions, in order.
  final List<String> _confirmedWork = [];

  String _labelOf(String id) => _catalogue.byId(id)?.label ?? id;

  /// Free chat → optional work suggestions → budget → checklist → measure →
  /// BOM. The
  /// renovation type and the room's size have their own screens, so the chat
  /// no longer asks for either.
  static const int _stepChat = 0;
  static const int _stepBudget = 1;
  static const int _stepDone = 2;

  /// Work item ids the AI just suggested, not yet added.
  List<String> _pendingRecommendations = [];
  final Set<String> _pendingSelected = {};
  bool _showBomChip = true;

  static const Color _cream = Color(0xFFEDE4D4);
  static const Color _darkBlue = Color(0xFF2C3E50);
  static const Color _navy = Color(0xFF1E3042);

  @override
  void initState() {
    super.initState();
    _startConversation();
  }

  void _startConversation() async {
    await _addBotMessage(
      "Hi! I'm the iConstruct AI Consultant for ${widget.projectName}.",
    );
    await Future.delayed(const Duration(milliseconds: 350));
    await _addBotMessage(
      "This is a ${widget.types.label.toLowerCase()} renovation: "
      "${widget.types.description.toLowerCase()}. Tell me what you want done "
      "and I'll suggest work from this project's checklist. When you're "
      "ready, tap Build my BOM to review the checklist, then measure the room "
      "so the quantities fit it.",
    );
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
    setState(() {
      _showBomChip = false;
      _pendingRecommendations = [];
      _pendingSelected.clear();
      _step = _stepBudget;
    });
    await _addBotMessage(
      "${_confirmedWork.isEmpty ? "You haven't added any work yet, so the checklist will start from the usual work for this project. " : ''}"
      "Before you review it: Low, Medium, or High budget for material "
      "quality? (Guides tier only — not a fixed price.)",
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
          "Thanks! Opening the checklist with the work you chose. Check it, "
          "then measure the room so the quantities fit it.",
        );
        _openChecklist();
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
      scope: widget.types.label,
      ideaLog: List<String>.from(_ideaLog),
      selectedMaterials: [for (final id in _confirmedWork) _labelOf(id)],
      projectNotes: widget.projectNotes,
      catalogue: _catalogue,
    );

    if (!mounted) return;
    setState(() => _isTyping = false);

    if (!result.success) {
      final reason = (result.errorMessage ?? '').trim();
      await _addBotMessage(
        "${reason.isEmpty ? 'iConstruct AI is unavailable right now.' : reason} "
        "You can still tap “Build my BOM” and pick the work from the "
        "checklist yourself — quantities are estimated for you.",
      );
      return;
    }

    final reply = result.reply.isNotEmpty
        ? result.reply
        : (result.inScope
            ? "Tell me more about the work you want — I only suggest; you decide."
            : "I can only help with iConstruct renovation planning for this estimate.");

    setState(() {
      _messages.add(ChatMessage(text: reply, isUser: false));
    });
    _scrollToBottom();

    // Work already on the list is not suggested again.
    final fresh = [
      for (final id in result.suggestedWork)
        if (!_confirmedWork.contains(id)) id,
    ];
    if (!result.inScope || fresh.isEmpty) {
      setState(() {
        _pendingRecommendations = [];
        _pendingSelected.clear();
        _showBomChip = true;
      });
      return;
    }

    _pendingRecommendations = fresh;
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
                                  'Suggested work',
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
                                _labelOf(name),
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
        "Nothing selected — that's fine. Keep describing your idea, or open suggestions again to pick some.",
      );
      return;
    }

    for (final id in _pendingSelected) {
      if (!_confirmedWork.contains(id)) _confirmedWork.add(id);
    }

    final picked = _pendingSelected.toList();
    setState(() {
      _messages.add(
        ChatMessage(
          text: 'I want to include: ${picked.map(_labelOf).join(', ')}',
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
      "Added ${picked.length} piece${picked.length == 1 ? '' : 's'} of work to "
      "your list (${_confirmedWork.length} so far). "
      "Tap the list icon anytime to see or remove what you chose. "
      "Share more ideas, or Build my BOM when you're satisfied.",
    );
  }

  Future<void> _openConfirmedWorkSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            void removeAt(int index) {
              setState(() => _confirmedWork.removeAt(index));
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
                                'Your work list',
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: _cream,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _confirmedWork.isEmpty
                                    ? 'Nothing here yet. Describe what you want, then pick from suggestions — I will not add work for you.'
                                    : 'This is the work you chose. Remove anything you do not want on the estimate.',
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
                  if (_confirmedWork.isEmpty)
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
                        itemCount: _confirmedWork.length,
                        separatorBuilder: (_, _) => const Divider(
                          color: Color(0x22EDE4D4),
                          height: 1,
                        ),
                        itemBuilder: (context, index) {
                          final name = _labelOf(_confirmedWork[index]);
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
                        label: _confirmedWork.isEmpty
                            ? 'Close'
                            : 'Done · ${_confirmedWork.length} selected',
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

  /// Opens the checklist with the work the builder chose in the chat ticked,
  /// or with the usual starting work when they chose none.
  void _openChecklist() {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => SelectWorkItemsScreen(
          catalogue: _catalogue,
          projectName: widget.projectName,
          customProjectName: widget.customProjectName,
          projectNotes: widget.projectNotes,
          coverage: widget.coverage,
          types: widget.types,
          hints: parseSiteHints(widget.projectNotes ?? ''),
          recommended: _confirmedWork.isEmpty
              ? null
              : {for (final id in _confirmedWork) id: ''},
          budgetPreference: _budget,
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
                        'AI Renovation\nConsultant',
                        style: GoogleFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          height: 1.15,
                        ),
                      ),
                    ),
                    _WorkListButton(
                      count: _confirmedWork.length,
                      onTap: _openConfirmedWorkSheet,
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
                  'Powered by AI API · iConstruct renovation planning only. You choose; I suggest.',
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
                label: _confirmedWork.isEmpty
                    ? 'Build my BOM'
                    : 'Build my BOM (${_confirmedWork.length})',
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

class _WorkListButton extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const _WorkListButton({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: count == 0
          ? 'Your work list, empty'
          : 'Your work list, $count selected',
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
