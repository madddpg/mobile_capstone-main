import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:iconstruct/features/project_creation/data/description_hints.dart';
import 'package:iconstruct/features/project_creation/data/renovation_coverage.dart';
import 'package:iconstruct/features/project_creation/data/renovation_scope.dart';
import 'package:iconstruct/features/project_creation/data/renovation_templates.dart';
import 'package:iconstruct/features/project_creation/screens/template_area_screen.dart';
import 'package:iconstruct/features/project_creation/widgets/glitched_flow_shell.dart';

/// The builder ticks the work the job includes, and the materials list is
/// built from those ticks.
///
/// Every item is pre-defined, with the materials it needs. The builder never
/// types work in and never deletes materials to shape the job: they pick a
/// package or tick items, and anything of the same kind left unticked is told
/// to the shop as not included.
class SelectWorkItemsScreen extends StatefulWidget {
  final WorkCatalogue catalogue;
  final String projectName;
  final String? customProjectName;
  final String? projectNotes;
  final RenovationCoverage coverage;

  /// The kinds of work chosen on the type step. They decide what starts
  /// ticked; the ticks then decide the kinds the estimate is saved as.
  final RenovationTypes types;
  final SiteHints hints;

  /// Work picked by the AI from the builder's description, ticked in place of
  /// the kinds' starting packages, with the AI's reason for each.
  final Map<String, String>? recommended;

  /// Budget tier from the AI chat, when the work was picked there.
  final String? budgetPreference;

  const SelectWorkItemsScreen({
    super.key,
    required this.catalogue,
    required this.projectName,
    this.customProjectName,
    this.projectNotes,
    this.coverage = RenovationCoverage.full,
    required this.types,
    this.hints = SiteHints.none,
    this.recommended,
    this.budgetPreference,
  });

  @override
  State<SelectWorkItemsScreen> createState() => _SelectWorkItemsScreenState();
}

class _SelectWorkItemsScreenState extends State<SelectWorkItemsScreen> {
  static const Map<RenovationScope, Color> _accents = {
    RenovationScope.cosmetic: Color(0xFF6EE7B7),
    RenovationScope.structural: Color(0xFFFBBF77),
    RenovationScope.functional: Color(0xFF8FB2D4),
  };

  late final Set<String> _selected = widget.recommended?.keys.toSet() ??
      widget.catalogue.startingSelection(widget.types);

  bool get _fromAi => widget.recommended != null;

  WorkCatalogue get _catalogue => widget.catalogue;

  bool get _hasStructural => _selected.any(
      (id) => _catalogue.byId(id)?.scope == RenovationScope.structural);

  void _toggle(String id) {
    setState(() {
      if (!_selected.remove(id)) _selected.add(id);
    });
  }

  void _pickPackage(WorkPackage package) {
    setState(() {
      _selected
        ..clear()
        ..addAll(package.itemIds);
    });
  }

  void _continue() {
    if (_selected.isEmpty) return;
    final types = _catalogue.typesOf(_selected);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TemplateAreaScreen(
          template: _catalogue.templateFor(_selected),
          projectName: widget.projectName,
          customProjectName: widget.customProjectName,
          projectNotes: widget.projectNotes,
          scope: types.primary,
          coverage: widget.coverage,
          renovationTypes: types,
          budgetPreference: widget.budgetPreference,
          hints: widget.hints,
        ),
      ),
    );
  }

  Text _heading(String text) => Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
          color: const Color(0xFF8FB2D4),
        ),
      );

  Text _note(String text, {Color color = const Color(0xFFE0D7C9)}) => Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: color,
          height: 1.35,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final matching = _catalogue.packageMatching(_selected);
    return GlitchedFlowShell(
      title: _fromAi ? 'Recommended\nWork' : 'What Work\nIs Included?',
      subtitle: widget.projectName,
      instruction: _fromAi
          ? 'Ticked from your description. Untick anything you do not want or '
              'tick more. The materials come from what you tick.'
          : 'Pick a package or tick each piece of work. The materials list is '
              'built from what you tick, and shops are told what you left out.',
      trailingAction: GlitchedPillButton(
        label: 'Continue',
        width: 150,
        onPressed: _selected.isEmpty ? null : _continue,
      ),
      body: ListView(
        padding: const EdgeInsets.only(right: 4, bottom: 8),
        children: [
          _heading('START FROM A PACKAGE'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final package in _catalogue.packages)
                _PackageChip(
                  label: package.label,
                  selected: identical(package, matching),
                  onTap: () => _pickPackage(package),
                ),
            ],
          ),
          for (final scope in RenovationScope.values)
            if (_catalogue.items.any((i) => i.scope == scope)) ...[
              const SizedBox(height: 20),
              _heading('${scope.label.toUpperCase()} WORK'),
              const SizedBox(height: 8),
              for (final item in _catalogue.items)
                if (item.scope == scope)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _WorkTile(
                      item: item,
                      reason: widget.recommended?[item.id],
                      accent: _accents[scope]!,
                      selected: _selected.contains(item.id),
                      onTap: () => _toggle(item.id),
                    ),
                  ),
            ],
          if (_hasStructural) ...[
            const SizedBox(height: 8),
            // Said wherever structural work is chosen: the app lists the
            // materials a structural job needs and nothing more.
            _note(
              'Material estimate only. No structural design or analysis.',
              color: const Color(0xFFFBBF77),
            ),
          ],
          if (_selected.isEmpty) ...[
            const SizedBox(height: 8),
            _note('Tick at least one piece of work to continue.'),
          ],
        ],
      ),
    );
  }
}

class _PackageChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _PackageChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? GlitchedFlowShell.cream : Colors.transparent,
      borderRadius: BorderRadius.circular(30),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(30),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: const Color(0xFF648DB6).withValues(alpha: 0.85),
              width: 1.2,
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: selected ? GlitchedFlowShell.darkBlue : Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

class _WorkTile extends StatelessWidget {
  final WorkItem item;

  /// Why the AI picked this item, when it did.
  final String? reason;
  final Color accent;
  final bool selected;
  final VoidCallback onTap;

  const _WorkTile({
    required this.item,
    this.reason,
    required this.accent,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      checked: selected,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 11, 12, 11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: selected ? accent.withValues(alpha: 0.10) : null,
              border: Border.all(
                color: selected
                    ? accent
                    : const Color(0xFF648DB6).withValues(alpha: 0.85),
                width: selected ? 1.6 : 1.2,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.label,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.detail,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: const Color(0xFFE0D7C9),
                          height: 1.35,
                        ),
                      ),
                      if ((reason ?? '').isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          'AI: $reason',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: accent,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: selected ? accent : Colors.white54,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
