import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:iconstruct/core/widgets/iconstruct_panel.dart';
import 'package:iconstruct/core/widgets/offset_panel_shell.dart';

/// Content chrome for Cost Estimation–style planning steps.
///
/// Layout chrome (cream curve, right-shifted navy offset panel, pill nav)
/// lives in [OffsetPanelShell]; this widget only supplies the titled card body.
class GlitchedFlowShell extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String instruction;
  final Widget body;
  final Widget? trailingAction;
  final bool showBackOnCard;

  const GlitchedFlowShell({
    super.key,
    required this.title,
    this.subtitle,
    required this.instruction,
    required this.body,
    this.trailingAction,
    this.showBackOnCard = true,
  });

  static const Color cream = IConstructPanel.cream;
  static const Color darkBlue = IConstructPanel.darkBlue;
  static const Color navyCard = IConstructPanel.navy;
  static const Color midBlue = IConstructPanel.midBlue;

  @override
  Widget build(BuildContext context) {
    return OffsetPanelShell(
      activeNav: OffsetNavTab.estimate,
      panelColor: IConstructPanel.navy,
      header: showBackOnCard
          ? OffsetPanelHeaders.backAndAvatar(context)
          : OffsetPanelHeaders.avatarAndMenu(context),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 1.15,
            ),
          ),
          if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              subtitle!,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: cream.withValues(alpha: 0.85),
              ),
            ),
          ],
          const SizedBox(height: 10),
          const Divider(color: cream, thickness: 1),
          const SizedBox(height: 10),
          Text(
            instruction,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: IConstructPanel.creamSoft,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          const Divider(color: cream, thickness: 1),
          const SizedBox(height: 12),
          Expanded(child: body),
          if (trailingAction != null) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: trailingAction!,
            ),
          ],
        ],
      ),
    );
  }
}

class GlitchedPillButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final double width;

  const GlitchedPillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.width = 150,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: 40,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: GlitchedFlowShell.cream,
          foregroundColor: GlitchedFlowShell.navyCard,
          disabledBackgroundColor:
              GlitchedFlowShell.cream.withValues(alpha: 0.4),
          shape: const StadiumBorder(),
          elevation: 6,
          shadowColor: Colors.black.withAlpha(100),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
