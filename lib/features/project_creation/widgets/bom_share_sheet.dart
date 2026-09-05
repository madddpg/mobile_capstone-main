import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:iconstruct/core/firebase/firestore_error.dart';
import 'package:iconstruct/features/project_creation/data/bom_export.dart';
import 'package:iconstruct/features/project_creation/data/bom_export_service.dart';
import 'package:iconstruct/core/widgets/app_message.dart';

const Color _cream = Color(0xFFEDE4D4);
const Color _navy = Color(0xFF1E3042);

/// Lets a builder hand the material list to a shop that does not use the app.
Future<void> showBomShareSheet(
  BuildContext context,
  BomExportData data,
) async {
  if (data.materials.isEmpty) {
    showAppMessage(context, 
      const SnackBar(content: Text('Add materials before sharing your list.')),
    );
    return;
  }

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext) => _BomShareSheet(data: data),
  );
}

class _BomShareSheet extends StatefulWidget {
  final BomExportData data;

  const _BomShareSheet({required this.data});

  @override
  State<_BomShareSheet> createState() => _BomShareSheetState();
}

class _BomShareSheetState extends State<_BomShareSheet> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action, String failureAction) async {
    if (_busy) return;
    setState(() => _busy = true);

    final navigator = Navigator.of(context);

    try {
      await action();
      if (mounted) navigator.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showAppMessage(context,
        SnackBar(content: Text(firestoreUserMessage(e, action: failureAction))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: const BoxDecoration(
        color: _navy,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: _cream.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Share material list',
              style: GoogleFonts.poppins(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${data.materials.length} materials · prices left blank for the '
              'shop to fill in. Useful for shops that quote in person or over '
              'chat.',
              style: GoogleFonts.poppins(
                fontSize: 11.5,
                height: 1.4,
                color: const Color(0xFFE0D7C9),
              ),
            ),
            const SizedBox(height: 18),
            _ShareOption(
              icon: Icons.picture_as_pdf_outlined,
              title: 'Share as PDF',
              subtitle: 'Best for email and printing at the shop',
              enabled: !_busy,
              onTap: () => _run(
                () => BomExportService.sharePdf(data),
                'share the PDF',
              ),
            ),
            const SizedBox(height: 10),
            _ShareOption(
              icon: Icons.image_outlined,
              title: 'Share as image',
              subtitle: 'Previews inline in Messenger and Viber',
              enabled: !_busy,
              onTap: () => _run(
                () => BomExportService.shareImages(data),
                'share the image',
              ),
            ),
            const SizedBox(height: 10),
            _ShareOption(
              icon: Icons.print_outlined,
              title: 'Print or save a copy',
              subtitle: 'Opens your printer or save-as-PDF options',
              enabled: !_busy,
              onTap: () => _run(
                () => BomExportService.printSheet(data),
                'open print preview',
              ),
            ),
            if (_busy) ...[
              const SizedBox(height: 18),
              Row(
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _cream,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Preparing your canvass sheet…',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: const Color(0xFFE0D7C9),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ShareOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool enabled;
  final VoidCallback onTap;

  const _ShareOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: const Color(0xFF648DB6).withValues(alpha: 0.85),
                width: 1.2,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: _cream.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: _cream, size: 21),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: GoogleFonts.poppins(
                          fontSize: 10.5,
                          color: const Color(0xFFE0D7C9),
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
      ),
    );
  }
}