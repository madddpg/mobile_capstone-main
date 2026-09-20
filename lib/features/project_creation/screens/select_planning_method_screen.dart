import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:iconstruct/features/project_creation/data/renovation_coverage.dart';
import 'package:iconstruct/features/project_creation/data/renovation_scope.dart';
import 'package:iconstruct/features/project_creation/screens/describe_project_screen.dart';
import 'package:iconstruct/features/project_creation/widgets/glitched_flow_shell.dart';

class SelectPlanningMethodScreen extends StatelessWidget {
  /// Project picked on the home screen (e.g. Kitchen Renovation).
  final String projectName;

  /// User-entered display name from the naming screen.
  final String? customProjectName;

  final RenovationScope scope;

  /// How much of the space the job covers. Its own dimension: a partial
  /// cosmetic job and a full one are the same kind of work over different
  /// amounts of room.
  final RenovationCoverage coverage;

  const SelectPlanningMethodScreen({
    super.key,
    required this.projectName,
    this.customProjectName,
    this.scope = RenovationScope.cosmetic,
    this.coverage = RenovationCoverage.full,
  });

  void _open(BuildContext context, PlanningMethod method) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DescribeProjectScreen(
          projectName: projectName,
          customProjectName: customProjectName,
          scope: scope,
          coverage: coverage,
          method: method,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayName = customProjectName?.isNotEmpty == true
        ? customProjectName!
        : projectName;

    return GlitchedFlowShell(
      title: 'Choose Planning\nMethod',
      subtitle: displayName,
      instruction:
          'Template = the standard materials for a ${scope.label.toLowerCase()} '
          '${projectName.toLowerCase()}.\nAI Planner = materials recommended '
          'from what you describe.',
      // The two tiles share the panel height when there is room. When there
      // is not, as on a small phone with large text, they keep their natural
      // height and the panel scrolls instead of clipping them.
      body: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Column(
                children: [
                  Expanded(
                    child: _MethodTile(
                      title: 'Plan with AI Planner',
                      subtitle:
                          'Describe what you want and get recommended materials, or chat with the AI consultant.',
                      icon: Icons.auto_awesome,
                      accent: const Color(0xFFC4B5FD),
                      onTap: () => _open(context, PlanningMethod.ai),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: _MethodTile(
                      title: 'Use Renovation Template',
                      subtitle:
                          'Start from the materials for your project and renovation type, then edit quantities or remove items.',
                      icon: Icons.grid_view_rounded,
                      accent: const Color(0xFF6EE7B7),
                      onTap: () => _open(context, PlanningMethod.template),
                    ),
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

class _MethodTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;

  const _MethodTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: const Color(0xFF648DB6).withValues(alpha: 0.85),
              width: 1.2,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 16, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: accent, size: 28),
                ),
                const Spacer(flex: 2),
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: const Color(0xFFE0D7C9),
                    height: 1.4,
                  ),
                ),
                const Spacer(),
                Align(
                  alignment: Alignment.centerRight,
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    color: const Color(0xFFEDE4D4).withValues(alpha: 0.85),
                    size: 22,
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
