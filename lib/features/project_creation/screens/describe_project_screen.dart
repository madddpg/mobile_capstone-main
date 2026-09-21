import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:iconstruct/core/widgets/app_message.dart';
import 'package:iconstruct/features/project_creation/data/description_hints.dart';
import 'package:iconstruct/features/project_creation/data/renovation_coverage.dart';
import 'package:iconstruct/features/project_creation/data/renovation_scope.dart';
import 'package:iconstruct/features/project_creation/data/renovation_templates.dart';
import 'package:iconstruct/features/project_creation/screens/ai_consultation_screen.dart';
import 'package:iconstruct/features/project_creation/screens/ai_recommendations_screen.dart';
import 'package:iconstruct/features/project_creation/screens/template_area_screen.dart';
import 'package:iconstruct/features/project_creation/widgets/glitched_flow_shell.dart';

enum PlanningMethod { ai, template }

/// The builder describes the job in their own words.
///
/// On the template path the description is saved with the estimate and shown
/// to shops. On the AI path it is what the AI recommends materials from; a
/// builder who would rather not write it out can chat with the AI instead.
class DescribeProjectScreen extends StatefulWidget {
  final String projectName;
  final String? customProjectName;
  final RenovationScope scope;

  /// How much of the space the job covers. Its own dimension: a partial
  /// cosmetic job and a full one are the same kind of work over different
  /// amounts of room.
  final RenovationCoverage coverage;
  final PlanningMethod method;

  const DescribeProjectScreen({
    super.key,
    required this.projectName,
    this.customProjectName,
    required this.scope,
    this.coverage = RenovationCoverage.full,
    required this.method,
  });

  @override
  State<DescribeProjectScreen> createState() => _DescribeProjectScreenState();
}

class _DescribeProjectScreenState extends State<DescribeProjectScreen> {
  final _controller = TextEditingController();

  /// Enough for one sentence about the work. Shorter than this, the AI has
  /// nothing to recommend from.
  static const int _minForRecommendations = 15;
  static const int _maxLength = 1000;

  bool get _isAi => widget.method == PlanningMethod.ai;
  String get _description => _controller.text.trim();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _example => switch (widget.scope) {
        RenovationScope.cosmetic =>
          'e.g. Repaint the walls off-white and replace the old floor tiles '
              'with 600x600 matte tiles.',
        RenovationScope.structural =>
          'e.g. Remove the wall between the kitchen and dining area and extend '
              'the room by 2 metres.',
        RenovationScope.functional =>
          'e.g. Replace the old G.I. water pipes with PPR and add two outlets '
              'near the counter.',
      };

  void _continue() {
    FocusScope.of(context).unfocus();
    if (_isAi) {
      if (_description.length < _minForRecommendations) {
        showAppMessage(
          context,
          const SnackBar(
            content: Text(
              'Describe the work in a sentence or two, or chat with the AI instead.',
            ),
          ),
        );
        return;
      }
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AiRecommendationsScreen(
            projectName: widget.projectName,
            customProjectName: widget.customProjectName,
            scope: widget.scope,
            coverage: widget.coverage,
            description: _description,
          ),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TemplateAreaScreen(
          template: RenovationTemplatesCatalog.forProject(
            widget.projectName,
            widget.scope,
          ),
          projectName: widget.projectName,
          customProjectName: widget.customProjectName,
          projectNotes: _description.isEmpty ? null : _description,
          scope: widget.scope,
          coverage: widget.coverage,
          hints: parseSiteHints(_description),
        ),
      ),
    );
  }

  void _openChat() {
    FocusScope.of(context).unfocus();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AIConsultationScreen(
          projectName: widget.projectName,
          customProjectName: widget.customProjectName,
          scope: widget.scope,
          coverage: widget.coverage,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hintStyle = GoogleFonts.poppins(
      fontSize: 11,
      color: const Color(0xFF8FB2D4),
      height: 1.35,
    );

    return GlitchedFlowShell(
      title: 'Describe\nYour Project',
      subtitle: '${widget.scope.label} · ${widget.projectName}',
      instruction: _isAi
          ? 'Tell us what you want done, in your own words. The AI recommends materials from it.'
          : 'Tell the shops what you want done. Anything you say about tiles, '
              'ceiling paint or removing old tiles is set on the next step.',
      trailingAction: GlitchedPillButton(
        label: _isAi ? 'Recommend' : 'Continue',
        width: 160,
        onPressed: _continue,
      ),
      body: ListView(
        padding: const EdgeInsets.only(right: 4, bottom: 24),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          Text(
            _isAi ? 'What do you want done? *' : 'What do you want done? (optional)',
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: GlitchedFlowShell.cream,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _controller,
            minLines: 6,
            maxLines: 10,
            maxLength: _maxLength,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => setState(() {}),
            scrollPadding: const EdgeInsets.only(bottom: 160),
            style: GoogleFonts.poppins(
              color: GlitchedFlowShell.darkBlue,
              fontSize: 14,
              height: 1.4,
            ),
            decoration: InputDecoration(
              hintText: _example,
              hintMaxLines: 4,
              hintStyle: GoogleFonts.poppins(
                fontSize: 13,
                color: GlitchedFlowShell.darkBlue.withValues(alpha: 0.45),
              ),
              counterStyle: hintStyle,
              filled: true,
              fillColor: GlitchedFlowShell.cream,
              contentPadding: const EdgeInsets.all(14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Mention the rooms or areas, what is wrong now, and what you want '
            'instead. Prices and labour are not covered here.',
            style: hintStyle,
          ),
          if (_isAi) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Divider(color: GlitchedFlowShell.cream.withAlpha(60)),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text('or', style: hintStyle),
                ),
                Expanded(
                  child: Divider(color: GlitchedFlowShell.cream.withAlpha(60)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _openChat,
              style: OutlinedButton.styleFrom(
                foregroundColor: GlitchedFlowShell.cream,
                side: BorderSide(color: GlitchedFlowShell.cream.withAlpha(140)),
                minimumSize: const Size.fromHeight(44),
                shape: const StadiumBorder(),
              ),
              icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
              label: Text(
                'Skip and chat with the AI instead',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
