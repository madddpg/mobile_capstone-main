import 'package:flutter/material.dart';

/// Geometry for iConstruct's signature **offset panel**.
///
/// Navy sheet shifted right with a cream gutter on the left, rounded on the
/// left (and top when tall), flush to the right edge — matching the
/// posted-project details / Name Estimate planning look.
class IConstructPanel {
  const IConstructPanel._();

  static const Color navy = Color(0xFF1E3042);
  static const Color darkBlue = Color(0xFF2C3E50);
  static const Color cream = Color(0xFFEDE4D4);
  static const Color creamSoft = Color(0xFFE0D7C9);
  static const Color midBlue = Color(0xFF648DB6);

  static const double pillHeight = 64;
  static const double pillBottomMargin = 12;
  static const double panelNavGap = 10;

  /// Left cream gutter. Widening this pushes the whole offset panel further
  /// right on every screen built with [OffsetPanelShell].
  static double leftInsetOf(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return (width * 0.23).clamp(78.0, 100.0);
  }

  static double railLeftOf(BuildContext context) =>
      (leftInsetOf(context) * 0.12).clamp(6.0, 8.0);

  static double railWidthOf(BuildContext context) =>
      leftInsetOf(context) - railLeftOf(context) - 6;

  static double headerHeightOf(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height;
    return (height * 0.085).clamp(70.0, 84.0);
  }

  static double topInsetOf(BuildContext context) =>
      headerHeightOf(context) + 10;

  /// Space reserved under a pinned panel so it sits just above the pill nav
  /// (no double SafeArea — that was leaving the large empty “error gap”).
  static double bottomInsetOf(BuildContext context) {
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    return pillHeight + pillBottomMargin + panelNavGap + bottomPad;
  }

  static double cornerRadiusOf(BuildContext context) {
    final side = MediaQuery.sizeOf(context).shortestSide;
    return (side * 0.12).clamp(40.0, 52.0);
  }

  /// Flush-right floating card: rounded left side.
  static BorderRadius offsetRadiusOf(BuildContext context) {
    final r = Radius.circular(cornerRadiusOf(context));
    return BorderRadius.only(topLeft: r, bottomLeft: r);
  }

  /// Tall fill panels (AI chat): round only the top-left. Right and bottom
  /// stay square so the sheet is flush to the screen edge, not hanging.
  static BorderRadius offsetTallRadiusOf(BuildContext context) {
    final r = Radius.circular(cornerRadiusOf(context));
    return BorderRadius.only(topLeft: r);
  }

  /// Centered chat card: rounded on every corner.
  static BorderRadius centeredRadiusOf(BuildContext context) {
    return BorderRadius.circular(cornerRadiusOf(context));
  }

  static EdgeInsets contentPaddingOf(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    // Extra left inset keeps titles (e.g. "Name Your Estimate") clear of the
    // rounded left edge; right stays a bit tighter because the panel is flush.
    final left = width < 360 ? 26.0 : 30.0;
    final right = width < 360 ? 18.0 : 22.0;
    return EdgeInsets.fromLTRB(left, 26, right, 22);
  }


  static double panelTopOf(BuildContext context) =>
      MediaQuery.paddingOf(context).top + topInsetOf(context);

  // Legacy aliases
  static const double leftInset = 60;
  static const double topInset = 90;
  static const double bottomInset = 80;
  static const double railLeft = 8;
  static const double headerHeight = 80;

  static const BorderRadius radius = BorderRadius.only(
    topLeft: Radius.circular(48),
    bottomLeft: Radius.circular(48),
  );
  static const BorderRadius flushRadius = BorderRadius.only(
    topLeft: Radius.circular(48),
    bottomLeft: Radius.circular(48),
  );
  static const BorderRadius topRadius = BorderRadius.only(
    topLeft: Radius.circular(48),
  );
  static const EdgeInsets contentPadding = EdgeInsets.fromLTRB(30, 26, 22, 22);

  static BorderRadius cardRadiusOf(BuildContext context) =>
      offsetRadiusOf(context);
  static BorderRadius flushRadiusOf(BuildContext context) =>
      offsetRadiusOf(context);
  static BorderRadius topRadiusOf(BuildContext context) {
    final r = Radius.circular(cornerRadiusOf(context));
    return BorderRadius.only(topLeft: r);
  }

  static double horizontalMarginOf(BuildContext context) =>
      leftInsetOf(context);
  static double maxPanelWidthOf(BuildContext context) =>
      MediaQuery.sizeOf(context).width;
  static double panelTop(BuildContext context) => panelTopOf(context);
}

/// Cream top shape: curve on the bottom-left, sharp on the right so nothing
/// peeks beside a flush-right navy panel.
class CreamBackdrop extends StatelessWidget {
  const CreamBackdrop({super.key});

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height;
    final blobHeight = height * 0.48;
    final radius = IConstructPanel.cornerRadiusOf(context) + 8;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      height: blobHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: IConstructPanel.cream,
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(radius),
          ),
        ),
      ),
    );
  }
}

/// Full-bleed cream under the status bar + header controls. Stops at the
/// navy panel’s top edge so the sheet can sit flush-right.
class CreamHeaderBand extends StatelessWidget {
  final Widget child;

  const CreamHeaderBand({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.paddingOf(context).top;
    final headerHeight = IConstructPanel.headerHeightOf(context);
    // Stop at the panel’s top edge. Painting cream *into* the navy card used
    // to hide a rounded top-right corner and made the sheet look hung.
    final coverHeight = IConstructPanel.panelTopOf(context);

    return Stack(
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: coverHeight,
          child: const ColoredBox(color: IConstructPanel.cream),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: topPad + headerHeight,
          child: Padding(
            padding: EdgeInsets.only(top: topPad),
            child: SizedBox(
              height: headerHeight,
              width: double.infinity,
              child: child,
            ),
          ),
        ),
      ],
    );
  }
}

/// Horizontal edge-to-edge stack. Bottom padding is handled by the shell’s
/// panel/nav geometry — applying SafeArea bottom here stacked a second inset
/// and created the large empty gap above the pill nav.
class OffsetSafeArea extends StatelessWidget {
  final Widget child;
  final bool bottom;

  const OffsetSafeArea({
    super.key,
    required this.child,
    this.bottom = false,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      left: false,
      right: false,
      bottom: bottom,
      top: false,
      child: child,
    );
  }
}
