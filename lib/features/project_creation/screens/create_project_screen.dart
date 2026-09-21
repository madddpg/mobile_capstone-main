import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:iconstruct/core/theme/app_theme.dart';
import 'package:iconstruct/features/project_creation/data/renovation_coverage.dart';
import 'package:iconstruct/features/project_creation/data/renovation_scope.dart';
import 'package:iconstruct/features/project_creation/screens/select_planning_method_screen.dart';
import 'package:iconstruct/features/project_creation/widgets/glitched_flow_shell.dart';

/// Names the estimate, then opens the AI or template choice.
class CreateProjectScreen extends StatefulWidget {
  final String renovationType;
  final RenovationScope scope;

  /// How much of the space the job covers. Its own dimension: a partial
  /// cosmetic job and a full one are the same kind of work over different
  /// amounts of room.
  final RenovationCoverage coverage;

  /// Every kind of work chosen, of which [scope] is the heaviest. Null from a
  /// caller that predates multi-select, which then means [scope] alone.
  final RenovationTypes? renovationTypes;

  RenovationTypes get types => renovationTypes ?? RenovationTypes.only(scope);

  const CreateProjectScreen({
    super.key,
    required this.renovationType,
    this.scope = RenovationScope.cosmetic,
    this.coverage = RenovationCoverage.full,
    this.renovationTypes,
  });

  @override
  State<CreateProjectScreen> createState() => _CreateProjectScreenState();
}

class _CreateProjectScreenState extends State<CreateProjectScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _continue() {
    if (!_formKey.currentState!.validate()) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SelectPlanningMethodScreen(
          projectName: widget.renovationType,
          customProjectName: _nameController.text.trim(),
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
      title: 'Name Your\nProject',
      subtitle: '${widget.types.label} · ${widget.renovationType}',
      instruction:
          'Next, choose how to plan materials: the AI Planner or a template.',
      trailingAction: GlitchedPillButton(
        label: 'Continue',
        onPressed: _continue,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.only(right: 4, bottom: 24),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            Text(
              'Project Name *',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: GlitchedFlowShell.cream,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _continue(),
              style: GoogleFonts.poppins(
                color: GlitchedFlowShell.darkBlue,
                fontSize: 14,
              ),
              decoration: _fieldDecoration('e.g. Master Bathroom Makeover'),
              scrollPadding: const EdgeInsets.only(bottom: 140),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Project name is required';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.poppins(
        fontSize: 13,
        color: GlitchedFlowShell.darkBlue.withValues(alpha: 0.45),
      ),
      filled: true,
      fillColor: GlitchedFlowShell.cream,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(
          color: const Color(0xFF648DB6).withValues(alpha: 0.35),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFF648DB6), width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: AppColors.warning),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: AppColors.warning, width: 1.4),
      ),
      errorStyle: GoogleFonts.poppins(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: AppColors.warning,
      ),
    );
  }
}
