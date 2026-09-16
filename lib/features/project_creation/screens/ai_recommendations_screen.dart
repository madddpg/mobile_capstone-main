import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:iconstruct/features/project_creation/data/ai_material_consultant_service.dart';
import 'package:iconstruct/features/project_creation/data/bom_quantity_estimator.dart';
import 'package:iconstruct/features/project_creation/data/renovation_scope.dart';
import 'package:iconstruct/features/project_creation/screens/ai_consultation_screen.dart';
import 'package:iconstruct/features/project_creation/screens/template_area_screen.dart';
import 'package:iconstruct/features/project_creation/widgets/glitched_flow_shell.dart';

/// Materials the AI recommends from the builder's description.
///
/// Every recommendation starts ticked, since the builder asked for them, and
/// nothing reaches the estimate unless it stays ticked. Quantities come after
/// the room is measured.
class AiRecommendationsScreen extends StatefulWidget {
  final String projectName;
  final String? customProjectName;
  final RenovationScope scope;
  final String description;

  /// Injected in tests; the app uses the Cloud Functions service.
  final AiMaterialConsultantService? service;

  const AiRecommendationsScreen({
    super.key,
    required this.projectName,
    this.customProjectName,
    required this.scope,
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

  bool _loading = true;
  String? _error;
  List<AiRecommendedMaterial> _materials = const [];
  final Set<int> _selected = {};

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
    final result = await _service.recommend(
      projectType: widget.projectName,
      scope: widget.scope.label,
      description: widget.description,
    );
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = result.success ? null : result.errorMessage;
      _materials = result.materials;
      _selected
        ..clear()
        ..addAll(List.generate(result.materials.length, (i) => i));
    });
  }

  void _continue() {
    final names = [
      for (var i = 0; i < _materials.length; i++)
        if (_selected.contains(i)) _materials[i].name,
    ];
    if (names.isEmpty) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TemplateAreaScreen(
          template: BomQuantityEstimator.consultationTemplate(
            projectType: widget.projectName,
            materialNames: names,
            scope: widget.scope,
          ),
          projectName: widget.projectName,
          customProjectName: widget.customProjectName,
          projectNotes: widget.description,
          scope: widget.scope,
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
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final count = _selected.length;
    return GlitchedFlowShell(
      title: 'Recommended\nMaterials',
      subtitle: '${widget.scope.label} · ${widget.projectName}',
      instruction:
          'Recommended from your description. Untick anything you do not want. Quantities are set after you measure.',
      trailingAction: GlitchedPillButton(
        label: count == 0 || _loading ? 'Continue' : 'Continue ($count)',
        width: 160,
        onPressed: _loading || count == 0 ? null : _continue,
      ),
      body: _loading
          ? _buildLoading()
          : _error != null
              ? _buildError(_error!)
              : _buildList(),
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

  Widget _buildError(String message) {
    return ListView(
      padding: const EdgeInsets.only(right: 4, bottom: 16),
      children: [
        Text(message, style: _bodyStyle),
        const SizedBox(height: 16),
        GlitchedPillButton(label: 'Try again', onPressed: _load),
        const SizedBox(height: 12),
        _chatButton(),
      ],
    );
  }

  Widget _chatButton() {
    return OutlinedButton.icon(
      onPressed: _openChat,
      style: OutlinedButton.styleFrom(
        foregroundColor: GlitchedFlowShell.cream,
        side: BorderSide(color: GlitchedFlowShell.cream.withAlpha(140)),
        minimumSize: const Size.fromHeight(44),
        shape: const StadiumBorder(),
      ),
      icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
      label: Text(
        'Chat with the AI instead',
        style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildList() {
    final allSelected = _selected.length == _materials.length;
    return ListView(
      padding: const EdgeInsets.only(right: 4, bottom: 16),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${_materials.length} recommended',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: GlitchedFlowShell.cream,
                ),
              ),
            ),
            TextButton(
              onPressed: () => setState(() {
                if (allSelected) {
                  _selected.clear();
                } else {
                  _selected.addAll(List.generate(_materials.length, (i) => i));
                }
              }),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF8FB2D4),
                visualDensity: VisualDensity.compact,
              ),
              child: Text(
                allSelected ? 'Untick all' : 'Tick all',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        for (var i = 0; i < _materials.length; i++) _materialRow(i),
        const SizedBox(height: 16),
        _chatButton(),
      ],
    );
  }

  Widget _materialRow(int index) {
    final material = _materials[index];
    final ticked = _selected.contains(index);
    return MergeSemantics(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => setState(() {
          ticked ? _selected.remove(index) : _selected.add(index);
        }),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: ticked,
                onChanged: (value) => setState(() {
                  value == true
                      ? _selected.add(index)
                      : _selected.remove(index);
                }),
                activeColor: GlitchedFlowShell.cream,
                checkColor: GlitchedFlowShell.darkBlue,
                side: const BorderSide(color: GlitchedFlowShell.cream),
                visualDensity: VisualDensity.compact,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        material.name,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      if (material.reason.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          material.reason,
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: const Color(0xFF8FB2D4),
                            height: 1.35,
                          ),
                        ),
                      ],
                    ],
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
