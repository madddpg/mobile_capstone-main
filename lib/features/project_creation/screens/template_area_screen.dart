import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:iconstruct/core/widgets/app_image.dart';
import 'package:iconstruct/features/auth/presentation/screens/cost_estimation.dart';
import 'package:iconstruct/features/project_creation/data/bom_quantity_estimator.dart';
import 'package:iconstruct/features/project_creation/data/renovation_scope.dart';
import 'package:iconstruct/features/project_creation/data/renovation_templates.dart';
import 'package:iconstruct/features/project_creation/widgets/glitched_flow_shell.dart';

/// After a template reference is chosen, collect project area and scope so quantities
/// can be auto-estimated per DPWH standards before opening the BOM review.
class TemplateAreaScreen extends StatefulWidget {
  final RenovationTemplate template;
  final String projectName;
  final String? customProjectName;
  final String? projectNotes;

  const TemplateAreaScreen({
    super.key,
    required this.template,
    required this.projectName,
    this.customProjectName,
    this.projectNotes,
  });

  @override
  State<TemplateAreaScreen> createState() => _TemplateAreaScreenState();
}

class _TemplateAreaScreenState extends State<TemplateAreaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _areaController = TextEditingController();
  RenovationScope _selectedScope = RenovationScope.fullRenovation;

  @override
  void dispose() {
    _areaController.dispose();
    super.dispose();
  }

  void _continue() {
    if (!_formKey.currentState!.validate()) return;
    final area = double.tryParse(_areaController.text.trim());
    if (area == null || !area.isFinite || area <= 0) return;

    final scaledItems = BomQuantityEstimator.scaleTemplate(
      template: widget.template,
      areaSqm: area,
      scope: _selectedScope,
    );
    final scaledTemplate = widget.template.copyWithItems(scaledItems);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CostEstimationScreen(
          projectName: widget.projectName,
          customProjectName: widget.customProjectName,
          projectNotes: widget.projectNotes,
          template: scaledTemplate,
          projectAreaSqm: area,
          scope: _selectedScope,
        ),
      ),
    );
  }

  void _showHowEstimationWorksDialog() {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E3042),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              const Icon(Icons.calculate_outlined, color: Color(0xFFEDE4D4)),
              const SizedBox(width: 10),
              Text(
                'How Estimation Works',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildGuideCard(
                  title: '1. DPWH National Standards',
                  body:
                      'All formulas follow DPWH Blue Book Vol III and Max Fajardo construction tables to ensure accurate quantities.',
                  icon: Icons.verified_outlined,
                ),
                const SizedBox(height: 10),
                _buildGuideCard(
                  title: '2. Renovation Scope',
                  body:
                      '• Full Renovation: Redo finishes (tiles, paint, fixtures & screed cement/sand).\n• Extension: Adds structural concrete, CHB masonry, rebar, & roof.',
                  icon: Icons.tune_outlined,
                ),
                const SizedBox(height: 10),
                _buildGuideCard(
                  title: '3. Dynamic Tile & Block Sizing',
                  body:
                      'Select material sizes in the BOM review to recalculate piece counts and grout/adhesive live.',
                  icon: Icons.aspect_ratio_outlined,
                ),
                const SizedBox(height: 10),
                _buildGuideCard(
                  title: '4. Master Foreman Essentials',
                  body:
                      'Includes tile spacers, teflon tape, adhesives, and an 8-10% waste buffer so your canvass list is 100% complete.',
                  icon: Icons.engineering_outlined,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Got it',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFEDE4D4),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildGuideCard({
    required String title,
    required String body,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF2C3E50),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEDE4D4).withAlpha(40)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: const Color(0xFF8FB2D4)),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFEDE4D4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: const Color(0xFFE0D7C9),
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GlitchedFlowShell(
      title: 'Project\nArea & Scope',
      subtitle: widget.template.name,
      instruction:
          'Select scope & total area (sqm). Quantities auto-estimate per Philippine DPWH national standards.',
      trailingAction: GlitchedPillButton(
        label: 'Estimate Qty',
        width: 168,
        onPressed: _continue,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.only(right: 4, bottom: 24),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            _ReferenceImage(template: widget.template),
            const SizedBox(height: 18),
            Row(
              children: [
                Text(
                  'Renovation Scope *',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: GlitchedFlowShell.cream,
                  ),
                ),
                const Spacer(),
                InkWell(
                  onTap: _showHowEstimationWorksDialog,
                  child: Row(
                    children: [
                      const Icon(
                        Icons.help_outline_rounded,
                        size: 14,
                        color: Color(0xFF8FB2D4),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'How it works',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF8FB2D4),
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFF1E3042),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: GlitchedFlowShell.cream.withAlpha(60)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildScopeOption(
                      scope: RenovationScope.fullRenovation,
                      title: 'Full Renovation',
                      subtitle: 'Finishes & Screed',
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: _buildScopeOption(
                      scope: RenovationScope.extension,
                      title: 'Extension',
                      subtitle: 'Structure + Finishes',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _selectedScope.description,
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: const Color(0xFF8FB2D4),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Total area (square meters) *',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: GlitchedFlowShell.cream,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _areaController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: GoogleFonts.poppins(
                color: GlitchedFlowShell.darkBlue,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              scrollPadding: const EdgeInsets.only(bottom: 140),
              decoration: InputDecoration(
                hintText: 'e.g. 18',
                hintStyle: GoogleFonts.poppins(
                  color: GlitchedFlowShell.darkBlue.withValues(alpha: 0.4),
                ),
                suffixText: 'sqm',
                filled: true,
                fillColor: GlitchedFlowShell.cream,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
              validator: (value) {
                final parsed = double.tryParse(value?.trim() ?? '');
                if (parsed == null || !parsed.isFinite || parsed <= 0) {
                  return 'Enter a valid area greater than 0';
                }
                if (parsed > 100000) {
                  return 'That area looks too large — check the value';
                }
                return null;
              },
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: GlitchedFlowShell.cream.withAlpha(20),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: GlitchedFlowShell.cream.withAlpha(40)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.verified_user_outlined, size: 20, color: Color(0xFF8FB2D4)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'DPWH & NSCP National Standards\nQuantities scale per sq.m with waste buffer.',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: const Color(0xFFE0D7C9),
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScopeOption({
    required RenovationScope scope,
    required String title,
    required String subtitle,
  }) {
    final selected = _selectedScope == scope;
    return GestureDetector(
      onTap: () => setState(() => _selectedScope = scope),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: selected ? GlitchedFlowShell.cream : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: selected ? GlitchedFlowShell.darkBlue : GlitchedFlowShell.cream,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 9,
                color: selected ? GlitchedFlowShell.darkBlue.withAlpha(180) : const Color(0xFF8FB2D4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sample / reference photo for the chosen template, shown at the top of the
/// area screen so the builder can see what this package is for. Falls back to a
/// labelled placeholder if the template has no image or it fails to load.
class _ReferenceImage extends StatelessWidget {
  final RenovationTemplate template;

  const _ReferenceImage({required this.template});

  @override
  Widget build(BuildContext context) {
    final url = template.imageUrl?.trim() ?? '';
    final asset = template.imageAsset?.trim() ?? '';

    Widget image;
    if (asset.isNotEmpty) {
      image = AppImage.asset(context, asset,
          height: 150, fit: BoxFit.cover, errorBuilder: (_, _, _) => _placeholder());
    } else if (url.isNotEmpty) {
      image = AppImage.network(context, url,
          height: 150, fit: BoxFit.cover, error: _placeholder());
    } else {
      image = _placeholder();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: [
          SizedBox(width: double.infinity, height: 150, child: image),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 20, 14, 10),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0xCC1E3042)],
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.image_outlined,
                      size: 14, color: Color(0xFFEDE4D4)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Reference — ${template.name}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFEDE4D4),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      alignment: Alignment.center,
      color: const Color(0xFF2C3E50),
      child: const Icon(Icons.home_work_outlined,
          size: 40, color: Color(0xFF8FB2D4)),
    );
  }
}
