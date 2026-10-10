import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:iconstruct/core/navigation/progress_guard.dart';
import 'package:iconstruct/features/project_creation/data/renovation_coverage.dart';
import 'package:iconstruct/features/project_creation/data/renovation_scope.dart';
import 'package:iconstruct/features/project_creation/data/renovation_templates.dart';
import 'package:iconstruct/features/project_creation/screens/create_project_screen.dart';
import 'package:iconstruct/features/project_creation/widgets/glitched_flow_shell.dart';

/// Second step of a new estimate: how much of the space, and what kind of work.
///
/// Two questions on one page. How much of the space is asked first because it
/// is the smaller decision and it frames the second: the type decides the
/// template, what the AI may recommend, and whether structural materials
/// belong in the estimate.
class SelectRenovationTypeScreen extends StatefulWidget {
  /// The project picked on the home screen, e.g. "Bathroom Renovation".
  final String renovationType;

  const SelectRenovationTypeScreen({super.key, required this.renovationType});

  @override
  State<SelectRenovationTypeScreen> createState() =>
      _SelectRenovationTypeScreenState();
}

class _SelectRenovationTypeScreenState
    extends State<SelectRenovationTypeScreen> {
  static const Map<RenovationScope, IconData> _icons = {
    RenovationScope.cosmetic: Icons.format_paint_outlined,
    RenovationScope.structural: Icons.foundation_outlined,
    RenovationScope.functional: Icons.plumbing_outlined,
  };

  static const Map<RenovationScope, Color> _accents = {
    RenovationScope.cosmetic: Color(0xFF6EE7B7),
    RenovationScope.structural: Color(0xFFFBBF77),
    RenovationScope.functional: Color(0xFF8FB2D4),
  };

  late final String _type =
      RenovationTemplatesCatalog.normalizeType(widget.renovationType);

  /// Whole space unless the builder says otherwise — the common case, and what
  /// every estimate saved before this question existed described.
  RenovationCoverage _coverage = RenovationCoverage.full;

  /// The kinds of work ticked. A real job is often more than one — retiling a
  /// bathroom and replacing its pipes — so any combination the project offers
  /// can be chosen. Starts with the project's usual kind already ticked.
  late final Set<RenovationScope> _selected = {
    RenovationTemplatesCatalog.defaultTypeFor(_type),
  };

  void _toggle(RenovationScope scope) {
    setState(() {
      if (!_selected.remove(scope)) _selected.add(scope);
    });
  }

  void _continue() {
    if (_selected.isEmpty) return;
    final types = RenovationTypes(_selected);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CreateProjectScreen(
          renovationType: widget.renovationType,
          // The heaviest kind, for everything that still holds one — chiefly
          // the projectScope label the shop dashboard reads.
          scope: types.primary,
          coverage: _coverage,
          renovationTypes: types,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GlitchedFlowShell(
      title: 'Type of\nRenovation',
      subtitle: _type,
      instruction:
          'Select every kind of work this job includes.',
      onBack: () => const LeaveWarning.exitEstimate(),
      onExit: () => const LeaveWarning.exitEstimate(),
      trailingAction: GlitchedPillButton(
        label: 'Continue',
        width: 150,
        onPressed: _selected.isEmpty ? null : _continue,
      ),
      body: ListView(
        padding: const EdgeInsets.only(right: 4, bottom: 8),
        children: [
          Text(
            'HOW MUCH OF THE SPACE',
            style: GoogleFonts.poppins(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
              color: const Color(0xFF8FB2D4),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              // Every project can be done whole, by half or in part.
              for (final coverage in RenovationCoverage.values)
                _CoverageChip(
                  coverage: coverage,
                  selected: _coverage == coverage,
                  onTap: () => setState(() => _coverage = coverage),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _coverage.description,
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: const Color(0xFFE0D7C9),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 22),
          Text(
            'KIND OF WORK · SELECT ALL THAT APPLY',
            style: GoogleFonts.poppins(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
              color: const Color(0xFF8FB2D4),
            ),
          ),
          const SizedBox(height: 8),
          for (var index = 0;
              index < RenovationScope.values.length;
              index++) ...[
            if (index > 0) const SizedBox(height: 12),
            Builder(builder: (context) {
              final scope = RenovationScope.values[index];
              final offered = RenovationTemplatesCatalog.offers(_type, scope);
              return _TypeTile(
                scope: scope,
                icon: _icons[scope]!,
                accent: _accents[scope]!,
                selected: _selected.contains(scope),
                unavailableReason: offered
                    ? null
                    : RenovationTemplatesCatalog.unavailableReason(_type, scope),
                onTap: offered ? () => _toggle(scope) : null,
              );
            }),
          ],
          if (_selected.contains(RenovationScope.structural)) ...[
            const SizedBox(height: 14),
            // Said wherever structural work is chosen, because the app lists
            // the materials a structural job needs and nothing more. Sizing a
            // beam or a footing is an engineer's call, not an estimate's.
            Text(
              'Material estimate only. No structural design or analysis.',
              style: GoogleFonts.poppins(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: const Color(0xFFFBBF77),
                height: 1.35,
              ),
            ),
          ],
          if (_selected.isEmpty) ...[
            const SizedBox(height: 14),
            Text(
              'Select at least one kind of work to continue.',
              style: GoogleFonts.poppins(
                fontSize: 11.5,
                color: const Color(0xFFE0D7C9),
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// One coverage option.
class _CoverageChip extends StatelessWidget {
  final RenovationCoverage coverage;
  final bool selected;
  final VoidCallback onTap;

  const _CoverageChip({
    required this.coverage,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      inMutuallyExclusiveGroup: true,
      selected: selected,
      child: Material(
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
              coverage.label,
              style: GoogleFonts.poppins(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: selected ? GlitchedFlowShell.darkBlue : Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TypeTile extends StatelessWidget {
  final RenovationScope scope;
  final IconData icon;
  final Color accent;
  final bool selected;
  final String? unavailableReason;
  final VoidCallback? onTap;

  const _TypeTile({
    required this.scope,
    required this.icon,
    required this.accent,
    required this.selected,
    required this.unavailableReason,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    // A tile now toggles rather than navigates, so it says which way it is.
    return Semantics(
      checked: enabled ? selected : null,
      child: Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              color: selected ? accent.withValues(alpha: 0.10) : null,
              border: Border.all(
                color: selected
                    ? accent
                    : const Color(0xFF648DB6).withValues(alpha: 0.85),
                width: selected ? 1.8 : 1.2,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: accent, size: 26),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        scope.label,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        unavailableReason ?? scope.description,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: const Color(0xFFE0D7C9),
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                if (enabled)
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
      ),
    );
  }
}
