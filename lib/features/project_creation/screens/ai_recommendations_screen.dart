import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:iconstruct/features/project_creation/data/ai_material_consultant_service.dart';
import 'package:iconstruct/features/project_creation/data/description_hints.dart';
import 'package:iconstruct/features/project_creation/data/renovation_coverage.dart';
import 'package:iconstruct/features/project_creation/data/renovation_scope.dart';
import 'package:iconstruct/features/project_creation/data/renovation_templates.dart';
import 'package:iconstruct/features/project_creation/screens/ai_consultation_screen.dart';
import 'package:iconstruct/features/project_creation/screens/select_work_items_screen.dart';
import 'package:iconstruct/features/project_creation/widgets/glitched_flow_shell.dart';

/// The AI reads the builder's description and picks the work it calls for.
///
/// The AI chooses only from the project's work items, never materials, so
/// everything it picks has the materials and formulas the checklist path
/// uses. Its picks open that checklist already ticked, with its reason under
/// each; the builder still decides what stays.
class AiRecommendationsScreen extends StatefulWidget {
  final String projectName;
  final String? customProjectName;
  final RenovationScope scope;

  /// How much of the space the job covers. Its own dimension: a partial
  /// cosmetic job and a full one are the same kind of work over different
  /// amounts of room.
  final RenovationCoverage coverage;

  /// Every kind of work chosen, of which [scope] is the heaviest. Null from a
  /// caller that predates multi-select, which then means [scope] alone.
  final RenovationTypes? renovationTypes;

  RenovationTypes get types => renovationTypes ?? RenovationTypes.only(scope);
  final String description;

  /// Injected in tests; the app uses the Cloud Functions service.
  final AiMaterialConsultantService? service;

  const AiRecommendationsScreen({
    super.key,
    required this.projectName,
    this.customProjectName,
    required this.scope,
    this.coverage = RenovationCoverage.full,
    this.renovationTypes,
    required this.description,
    this.service,
  });

  @override
  State<AiRecommendationsScreen> createState() =>
      _AiRecommendationsScreenState();
}

class _AiRecommendationsScreenState extends State<AiRecommendationsScreen> {
  late final AiMaterialConsultantService _service =
      widget.service ?? AiMaterialConsultantService();

  late final WorkCatalogue _catalogue =
      RenovationTemplatesCatalog.workCatalogueFor(widget.projectName);

  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await _service.recommendWork(
      projectType: widget.projectName,
      scope: widget.types.label,
      description: widget.description,
      catalogue: _catalogue,
    );
    if (!mounted) return;
    if (!result.success) {
      setState(() {
        _loading = false;
        _error = result.errorMessage;
      });
      return;
    }
    _openChecklist({for (final pick in result.picks) pick.id: pick.reason});
  }

  /// The checklist, ticked with [recommended] when the AI answered, or with
  /// the starting packages for the chosen kinds of work when it did not.
  /// Either way the description carries over as the estimate's notes.
  void _openChecklist([Map<String, String>? recommended]) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => SelectWorkItemsScreen(
          catalogue: _catalogue,
          projectName: widget.projectName,
          customProjectName: widget.customProjectName,
          projectNotes: widget.description,
          coverage: widget.coverage,
          types: widget.types,
          hints: parseSiteHints(widget.description),
          recommended: recommended,
        ),
      ),
    );
  }

  void _openChat() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => AIConsultationScreen(
          projectName: widget.projectName,
          customProjectName: widget.customProjectName,
          projectNotes: widget.description,
          scope: widget.scope,
          coverage: widget.coverage,
          renovationTypes: widget.types,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GlitchedFlowShell(
      title: 'Recommended\nWork',
      subtitle: '${widget.types.label} · ${widget.projectName}',
      instruction:
          'The AI picks the work your description calls for from this '
          'project\'s checklist. You can change any of it next.',
      body: _loading ? _buildLoading() : _buildError(_error ?? ''),
    );
  }

  TextStyle get _bodyStyle => GoogleFonts.poppins(
        fontSize: 12,
        color: const Color(0xFFE0D7C9),
        height: 1.4,
      );

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: GlitchedFlowShell.cream),
          const SizedBox(height: 14),
          Text('Reading your description…', style: _bodyStyle),
        ],
      ),
    );
  }

  Widget _outlined(String label, IconData icon, VoidCallback onPressed) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: GlitchedFlowShell.cream,
        side: BorderSide(color: GlitchedFlowShell.cream.withAlpha(140)),
        minimumSize: const Size.fromHeight(44),
        shape: const StadiumBorder(),
      ),
      icon: Icon(icon, size: 18),
      label: Text(
        label,
        textAlign: TextAlign.center,
        style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildError(String message) {
    return ListView(
      padding: const EdgeInsets.only(right: 4, bottom: 16),
      children: [
        Text(message, style: _bodyStyle),
        const SizedBox(height: 16),
        GlitchedPillButton(label: 'Try again', onPressed: _load),
        const SizedBox(height: 12),
        // The checklist needs no model and no network beyond Firestore, so it
        // is the way through when the AI is busy — not a consolation prize.
        _outlined(
          'Pick the work from the checklist instead',
          Icons.checklist_rounded,
          _openChecklist,
        ),
        const SizedBox(height: 10),
        _outlined(
          'Chat with the AI instead',
          Icons.chat_bubble_outline_rounded,
          _openChat,
        ),
      ],
    );
  }
}
