import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:iconstruct/core/widgets/app_image.dart';
import 'package:iconstruct/features/project_creation/screens/template_area_screen.dart';
import 'package:iconstruct/features/project_creation/data/renovation_template_service.dart';
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
  final _service = RenovationTemplateService();
  late Future<List<RenovationTemplate>> _future;

  @override
  void initState() {
    super.initState();
    _future = _service.fetchTemplatesForType(widget.projectName);
  }

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
      body: FutureBuilder<List<RenovationTemplate>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: GlitchedFlowShell.cream,
                ),
              ),
            );
          }

          final templates = snapshot.data ??
              RenovationTemplatesCatalog.threeForType(typeLabel);

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
              _TemplatePreview(template: template),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            template.name,
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
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

class _TemplatePreview extends StatelessWidget {
  final RenovationTemplate template;

  const _TemplatePreview({required this.template});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: 72,
        height: 72,
        child: _buildImage(),
      ),
    );
  }

  Widget _buildImage() {
    final asset = template.imageAsset?.trim();
    final url = template.imageUrl?.trim();

    if (asset != null && asset.isNotEmpty) {
      return Builder(
        builder: (context) => AppImage.asset(
          context,
          asset,
          width: 72,
          height: 72,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _fallback(),
        ),
      );
    }

    if (url != null && url.isNotEmpty) {
      return Builder(
        builder: (context) => AppImage.network(
          context,
          url,
          width: 72,
          height: 72,
          fit: BoxFit.cover,
          error: _fallback(),
        ),
      );
    }

    return _fallback();
  }

  Widget _fallback() {
    final key = RenovationTemplatesCatalog.styleKey(template.style);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _styleAccent(key).withValues(alpha: 0.35),
            GlitchedFlowShell.navyCard,
          ],
        ),
      ),
      child: Center(
        child: Icon(
          _styleIcon(key),
          size: 30,
          color: GlitchedFlowShell.cream,
        ),
      ),
    );
  }

  IconData _styleIcon(String styleKey) {
    switch (styleKey) {
      case 'minimalist':
        return Icons.crop_square_rounded;
      case 'traditional':
        return Icons.villa_outlined;
      case 'modern':
      default:
        return Icons.auto_awesome_mosaic_outlined;
    }
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
