import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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

  late final List<RenovationCoverage> _offeredCoverages =
      RenovationTemplatesCatalog.coveragesFor(_type);

  /// Whole space unless the builder says otherwise — the common case, and what
  /// every estimate saved before this question existed described.
  late RenovationCoverage _coverage = _offeredCoverages.first;

  void _choose(RenovationScope scope) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CreateProjectScreen(
          renovationType: widget.renovationType,
          scope: scope,
          coverage: _coverage,
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
          'How much of the space, and what kind of work? Together they decide which materials the template and the AI start from.',
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
              for (final coverage in RenovationCoverage.values)
                _CoverageChip(
                  coverage: coverage,
                  selected: _coverage == coverage,
                  // An option this project cannot be is hidden by being
                  // unpickable and saying why, rather than silently missing.
                  unavailableReason: _offeredCoverages.contains(coverage)
                      ? null
                      : RenovationTemplatesCatalog.unavailableCoverageReason(
                          _type, coverage),
                  onTap: _offeredCoverages.contains(coverage)
                      ? () => setState(() => _coverage = coverage)
                      : null,
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
            'KIND OF WORK',
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
                unavailableReason: offered
                    ? null
                    : RenovationTemplatesCatalog.unavailableReason(_type, scope),
                onTap: offered ? () => _choose(scope) : null,
              );
            }),
          ],
        ],
      ),
    );
  }
}

/// One coverage option. Unpickable options stay on screen with the reason,
/// so the builder learns what the project can be rather than what is missing.
class _CoverageChip extends StatelessWidget {
  final RenovationCoverage coverage;
  final bool selected;
  final String? unavailableReason;
  final VoidCallback? onTap;

  const _CoverageChip({
    required this.coverage,
    required this.selected,
    required this.unavailableReason,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Tooltip(
      message: unavailableReason ?? '',
      triggerMode:
          enabled ? TooltipTriggerMode.manual : TooltipTriggerMode.tap,
      child: Opacity(
        opacity: enabled ? 1 : 0.45,
        child: Material(
          color: selected
              ? GlitchedFlowShell.cream
              : Colors.transparent,
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
                  color: selected
                      ? GlitchedFlowShell.darkBlue
                      : Colors.white,
                ),
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
  final String? unavailableReason;
  final VoidCallback? onTap;

  const _TypeTile({
    required this.scope,
    required this.icon,
    required this.accent,
    required this.unavailableReason,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Opacity(
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
              border: Border.all(
                color: const Color(0xFF648DB6).withValues(alpha: 0.85),
                width: 1.2,
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
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.white70,
                    size: 22,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
