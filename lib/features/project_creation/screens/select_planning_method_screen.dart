import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:iconstruct/features/project_creation/screens/ai_consultation_screen.dart';
import 'package:iconstruct/features/project_creation/screens/select_template_screen.dart';
import 'package:iconstruct/features/project_creation/widgets/glitched_flow_shell.dart';

class SelectPlanningMethodScreen extends StatelessWidget {
  /// Renovation category (e.g. Kitchen Renovation).
  final String projectName;

  /// User-entered display name from the estimate naming screen.
  final String? customProjectName;
  final String? projectNotes;

  const SelectPlanningMethodScreen({
    super.key,
    required this.projectName,
    this.customProjectName,
    this.projectNotes,
  });

  @override
  Widget build(BuildContext context) {
    final displayName = customProjectName?.isNotEmpty == true
        ? customProjectName!
        : projectName;

    return GlitchedFlowShell(
      title: 'Choose Planning\nMethod',
      subtitle: displayName,
      instruction:
          'Template = pre-defined materials.\nAI Planner = custom material list.',
      body: Column(
        children: [
          Expanded(
            child: _MethodTile(
              title: 'Plan with AI Planner',
              subtitle:
                  'Chat with the AI consultant to generate a custom Bill of Materials.',
              icon: Icons.auto_awesome,
              accent: const Color(0xFFC4B5FD),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AIConsultationScreen(
                      projectName: projectName,
                      customProjectName: customProjectName,
                      projectNotes: projectNotes,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: _MethodTile(
              title: 'Use Renovation Template',
              subtitle:
                  'Pick a style template with pre-defined materials, then edit quantities or remove items.',
              icon: Icons.grid_view_rounded,
              accent: const Color(0xFF6EE7B7),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SelectTemplateScreen(
                      projectName: projectName,
                      customProjectName: customProjectName,
                      projectNotes: projectNotes,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
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
