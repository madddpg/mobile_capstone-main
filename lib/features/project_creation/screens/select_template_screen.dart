import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:iconstruct/features/project_creation/screens/template_area_screen.dart';
import 'package:iconstruct/features/project_creation/data/renovation_templates.dart';
import 'package:iconstruct/features/project_creation/widgets/glitched_flow_shell.dart';

class SelectTemplateScreen extends StatefulWidget {
  final String projectName;
  final String? customProjectName;
  final String? projectNotes;

  const SelectTemplateScreen({
    super.key,
    required this.projectName,
    this.customProjectName,
    this.projectNotes,
  });

  @override
  State<SelectTemplateScreen> createState() => _SelectTemplateScreenState();
}

class _SelectTemplateScreenState extends State<SelectTemplateScreen> {
  void _openTemplate(RenovationTemplate template) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TemplateAreaScreen(
          template: template,
          projectName: widget.projectName,
          customProjectName: widget.customProjectName,
          projectNotes: widget.projectNotes,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final typeLabel =
        RenovationTemplatesCatalog.normalizeType(widget.projectName);

    return GlitchedFlowShell(
      title: 'Select\nTemplate',
      subtitle: typeLabel,
      instruction:
          'Three reference styles for $typeLabel.\nQuantities scale from the area you enter next.',
      body: Builder(
        builder: (context) {
          // Templates are fixed in the app. Firestore templates used to win
          // over these, and the seeded ones carried no per-sqm rates, so a
          // kitchen backsplash came out at 2,113 subway tiles.
          final templates = RenovationTemplatesCatalog.threeForType(typeLabel);

          if (templates.isEmpty) {
            return Text(
              'No templates available yet.',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: const Color(0xFFE0D7C9),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.only(right: 4, bottom: 8),
            itemCount: templates.length + 1,
            separatorBuilder: (_, _) => const SizedBox(height: 14),
            itemBuilder: (context, index) {
              if (index == templates.length) {
                return Text(
                  'Templates are references only — you can swap, edit or remove '
                  'materials before requesting quotations.',
                  style: GoogleFonts.poppins(
                    fontSize: 10.5,
                    color: const Color(0xFFE0D7C9).withValues(alpha: 0.75),
                    height: 1.4,
                  ),
                );
              }

              final template = templates[index];
              return _GlitchedTemplateTile(
                template: template,
                onTap: () => _openTemplate(template),
              );
            },
          );
        },
      ),
    );
  }
}

class _GlitchedTemplateTile extends StatelessWidget {
  final RenovationTemplate template;
  final VoidCallback onTap;

  const _GlitchedTemplateTile({
    required this.template,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: const Color(0xFF648DB6).withValues(alpha: 0.85),
              width: 1.2,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Wrap, not Row: on a narrow phone the style badge drops
                    // under the name instead of running past the tile edge.
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          template.name,
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        _StyleBadge(style: template.style),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      template.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: const Color(0xFFE0D7C9),
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${template.items.length} materials',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF8FB2D4),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Colors.white70,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Color _styleAccent(String styleKey) {
  switch (styleKey) {
    case 'minimalist':
      return const Color(0xFF6EE7B7);
    case 'traditional':
      return const Color(0xFFFBBF77);
    case 'modern':
    default:
      return const Color(0xFF8FB2D4);
  }
}

class _StyleBadge extends StatelessWidget {
  final String style;

  const _StyleBadge({required this.style});

  @override
  Widget build(BuildContext context) {
    final key = RenovationTemplatesCatalog.styleKey(style);
    final accent = _styleAccent(key);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.6)),
      ),
      child: Text(
        RenovationTemplatesCatalog.styleLabel(key),
        style: GoogleFonts.poppins(
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          color: accent,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
