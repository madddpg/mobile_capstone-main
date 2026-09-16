import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:iconstruct/features/project_creation/data/renovation_scope.dart';
import 'package:iconstruct/features/project_creation/data/renovation_templates.dart';
import 'package:iconstruct/features/project_creation/screens/create_project_screen.dart';
import 'package:iconstruct/features/project_creation/widgets/glitched_flow_shell.dart';

/// Second step of a new estimate: what kind of renovation the project is.
///
/// The type decides the template, what the AI may recommend, and whether
/// structural materials belong in the estimate.
class SelectRenovationTypeScreen extends StatelessWidget {
  /// The project picked on the home screen, e.g. "Bathroom Renovation".
  final String renovationType;

  const SelectRenovationTypeScreen({super.key, required this.renovationType});

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

  void _choose(BuildContext context, RenovationScope scope) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CreateProjectScreen(
          renovationType: renovationType,
          scope: scope,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final type = RenovationTemplatesCatalog.normalizeType(renovationType);
    return GlitchedFlowShell(
      title: 'Type of\nRenovation',
      subtitle: type,
      instruction:
          'What kind of work is this? It decides which materials the template and the AI start from.',
      body: ListView.separated(
        padding: const EdgeInsets.only(right: 4, bottom: 8),
        itemCount: RenovationScope.values.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final scope = RenovationScope.values[index];
          final offered = RenovationTemplatesCatalog.offers(type, scope);
          return _TypeTile(
            scope: scope,
            icon: _icons[scope]!,
            accent: _accents[scope]!,
            unavailableReason: offered
                ? null
                : RenovationTemplatesCatalog.unavailableReason(type, scope),
            onTap: offered ? () => _choose(context, scope) : null,
          );
        },
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
