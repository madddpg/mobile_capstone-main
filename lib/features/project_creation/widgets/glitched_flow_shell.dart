import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:iconstruct/core/navigation/progress_guard.dart';
import 'package:iconstruct/core/widgets/iconstruct_panel.dart';
import 'package:iconstruct/core/widgets/keyboard_form.dart';
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

  /// See [ProgressGuard.onBack].
  final LeaveWarning? Function()? onBack;

  /// See [ProgressGuard.onExit].
  final LeaveWarning? Function()? onExit;

  const GlitchedFlowShell({
    super.key,
    required this.title,
    this.subtitle,
    required this.instruction,
    required this.body,
    this.trailingAction,
    this.showBackOnCard = true,
    this.onBack,
    this.onExit,
  });

  static const Color cream = IConstructPanel.cream;
  static const Color darkBlue = IConstructPanel.darkBlue;
  static const Color navyCard = IConstructPanel.navy;
  static const Color midBlue = IConstructPanel.midBlue;

  @override
  Widget build(BuildContext context) {
    return ProgressGuard(
      onBack: onBack,
      onExit: onExit,
      child: _buildShell(context),
    );
  }

  Widget _buildShell(BuildContext context) {
    return OffsetPanelShell(
      activeNav: OffsetNavTab.estimate,
      panelColor: IConstructPanel.navy,
      header: showBackOnCard
          ? OffsetPanelHeaders.backAndAvatar(context)
          : OffsetPanelHeaders.avatarAndMenu(context),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: RevealFocusedField(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return _StablePanelScroll(
                    viewport: constraints.maxHeight,
                    header: _header(),
                    body: body,
                  );
                },
              ),
            ),
          ),
          if (trailingAction != null) ...[
            const SizedBox(height: 10),
            Align(alignment: Alignment.centerRight, child: trailingAction!),
          ],
        ],
      ),
    );
  }

  Widget _header() {
    return Column(
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
      ],
    );
  }
}

/// Scrolls the title off when the keyboard shrinks the panel, and keeps
/// [body] in a bounded box so existing lists still lay out.
///
/// The scroll view is mounted at every height. Inserting it only after the
/// keyboard opens would rebuild the focused field and dismiss the keyboard.
class _StablePanelScroll extends StatelessWidget {
  const _StablePanelScroll({
    required this.viewport,
    required this.header,
    required this.body,
  });

  final double viewport;
  final Widget header;
  final Widget body;

  /// Room kept for the title block when deciding how tall the body is.
  static const double _headerReserve = 168;

  /// Smallest body box, so a field can still be scrolled into view when the
  /// visible panel is shorter than the title.
  static const double _bodyMin = 180;

  @override
  Widget build(BuildContext context) {
    final bodyHeight = math.max(_bodyMin, viewport - _headerReserve);
    final extent = math.max(viewport, _headerReserve + bodyHeight);
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: viewport),
        child: SizedBox(
          height: extent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              header,
              Expanded(child: body),
            ],
          ),
        ),
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
    // Minimum size, not a fixed one: the label grows with the screen and the
    // phone's font setting, and a fixed height cut it off inside the button,
    // where no overflow warning is ever raised. The width is a preference
    // and never wider than the panel.
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final minWidth = width.clamp(0.0, maxWidth).toDouble();
        return Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton(
            onPressed: onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: GlitchedFlowShell.cream,
              foregroundColor: GlitchedFlowShell.navyCard,
              disabledBackgroundColor: GlitchedFlowShell.cream.withValues(
                alpha: 0.4,
              ),
              minimumSize: Size(minWidth, 48),
              maximumSize: Size(maxWidth, 96),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: const StadiumBorder(),
              elevation: 6,
              shadowColor: Colors.black.withAlpha(100),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        );
      },
    );
  }
}
