import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:iconstruct/core/widgets/iconstruct_panel.dart';
import 'package:iconstruct/core/widgets/offset_pill_nav.dart';
import 'package:iconstruct/core/widgets/user_avatar.dart';
import 'package:iconstruct/features/auth/presentation/screens/profile_screen.dart';

export 'package:iconstruct/core/widgets/offset_pill_nav.dart'
    show OffsetNavTab, OffsetPillNav;

/// How the navy offset panel is laid out inside [OffsetPanelShell].
enum OffsetPanelExtent {
  /// Floating card sitting just above the pill nav.
  pinnedWithNav,

  /// Centered navy card above the pill nav (shop chat).
  centeredWithNav,

  /// Panel stretches to the bottom (AI chat).
  fillBottom,

  /// Scrollable column of offset cards.
  scrollBody,
}

/// Shared offset-panel shell for Name Estimate, AI Consultant, BOM review, etc.
///
/// Cream top curve, navy card shifted right / flush to the right edge, floating
/// pill nav. Bottom SafeArea is not applied to the stack so the panel-to-nav
/// gap stays tight and intentional.
class OffsetPanelShell extends StatelessWidget {
  final Widget header;
  final Widget body;
  final Widget? overlay;
  final OffsetPanelExtent extent;
  final bool wrapPanel;
  final EdgeInsetsGeometry? contentPadding;
  final BorderRadius? borderRadius;
  final Color? panelColor;
  final OffsetNavTab? activeNav;
  final GlobalKey<ScaffoldState>? scaffoldKey;
  final Widget? endDrawer;
  final bool safeAreaBottom;

  const OffsetPanelShell({
    super.key,
    required this.header,
    required this.body,
    this.overlay,
    this.extent = OffsetPanelExtent.pinnedWithNav,
    this.wrapPanel = true,
    this.contentPadding,
    this.borderRadius,
    this.panelColor,
    this.activeNav,
    this.scaffoldKey,
    this.endDrawer,
    this.safeAreaBottom = false,
  });

  @override
  Widget build(BuildContext context) {
    return _KeyboardInsetBuilder(
      builder: (context, keyboardInset) {
        final showNav = activeNav != null;
        final keyboardOpen = keyboardInset > 24;
        final liftAboveNav = extent == OffsetPanelExtent.pinnedWithNav ||
            extent == OffsetPanelExtent.centeredWithNav;
        final navOrSafe = showNav && liftAboveNav
            ? IConstructPanel.bottomInsetOf(context)
            : MediaQuery.paddingOf(context).bottom;
        // Scaffold already shrinks by MediaQuery viewInsets; only pad leftover
        // height from the raw Flutter view (common on edge-to-edge Android).
        final mediaInset = MediaQuery.viewInsetsOf(context).bottom;
        final extraInset = (keyboardInset - mediaInset).clamp(0.0, 600.0);
        final bottomClearance = keyboardOpen ? 0.0 : navOrSafe;

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: const SystemUiOverlayStyle(
            statusBarColor: IConstructPanel.cream,
            statusBarIconBrightness: Brightness.dark,
            statusBarBrightness: Brightness.light,
          ),
          child: Scaffold(
            key: scaffoldKey,
            backgroundColor: IConstructPanel.cream,
            resizeToAvoidBottomInset: true,
            endDrawer: endDrawer,
            body: Container(
              width: double.infinity,
              height: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.0, 0.42, 1.0],
                  colors: [
                    IConstructPanel.cream,
                    IConstructPanel.darkBlue,
                    IConstructPanel.midBlue,
                  ],
                ),
              ),
              child: OffsetSafeArea(
                bottom: safeAreaBottom,
                child: Padding(
                  padding: EdgeInsets.only(bottom: extraInset),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const CreamBackdrop(),
                      CreamHeaderBand(child: header),
                      if (extent == OffsetPanelExtent.scrollBody)
                        _buildScrollBody(
                          context,
                          showNav: showNav && !keyboardOpen,
                          keyboardInset: 0,
                        )
                      else
                        _buildOffsetPanel(context, bottom: bottomClearance),
                      if (overlay != null) overlay!,
                      if (showNav && !keyboardOpen)
                        OffsetPillNav(activeTab: activeNav!),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildOffsetPanel(BuildContext context, {required double bottom}) {
    final centered = extent == OffsetPanelExtent.centeredWithNav;
    final rawRadius = borderRadius ??
        (centered
            ? IConstructPanel.centeredRadiusOf(context)
            : extent == OffsetPanelExtent.fillBottom
            ? IConstructPanel.offsetTallRadiusOf(context)
            : IConstructPanel.offsetRadiusOf(context));
    // Offset sheets stay flush-right. Centered chat keeps all corners rounded.
    final radius = centered
        ? rawRadius
        : rawRadius.copyWith(
            topRight: Radius.zero,
            bottomRight: Radius.zero,
            bottomLeft: extent == OffsetPanelExtent.fillBottom
                ? Radius.zero
                : rawRadius.bottomLeft,
          );
    final padding =
        contentPadding ?? IConstructPanel.contentPaddingOf(context);

    Widget child = body;
    if (wrapPanel) {
      child = SizedBox.expand(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: panelColor ?? IConstructPanel.navy,
            borderRadius: radius,
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 12,
                offset: Offset(-6, 8),
              ),
            ],
          ),
          child: Padding(
            padding: padding,
            child: body,
          ),
        ),
      );
    }

    final side = IConstructPanel.leftInsetOf(context);
    return Positioned(
      top: IConstructPanel.panelTopOf(context),
      left: centered ? (side * 0.28).clamp(16.0, 28.0) : side,
      right: centered ? (side * 0.28).clamp(16.0, 28.0) : 0,
      bottom: bottom,
      child: child,
    );
  }

  Widget _buildScrollBody(
    BuildContext context, {
    required bool showNav,
    required double keyboardInset,
  }) {
    final bottomPad = keyboardInset > 0
        ? keyboardInset + 16
        : (showNav ? IConstructPanel.bottomInsetOf(context) + 8 : 24.0);

    return Positioned.fill(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          IConstructPanel.leftInsetOf(context),
          IConstructPanel.panelTopOf(context),
          0,
          bottomPad,
        ),
        child: body,
      ),
    );
  }
}

/// Common header rows for offset screens.
class OffsetPanelHeaders {
  const OffsetPanelHeaders._();

  static Widget backAndAvatar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _BackButton(onTap: () => Navigator.pop(context)),
          const Spacer(),
          UserAvatar(
            size: 36,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ProfileScreen(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  static Widget avatarAndMenu(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          UserAvatar(
            size: 36,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ProfileScreen(),
                ),
              );
            },
          ),
          SizedBox(
            width: 28,
            height: 28,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  width: 18,
                  height: 2.4,
                  color: IConstructPanel.darkBlue,
                ),
                const SizedBox(height: 4),
                Container(
                  width: 14,
                  height: 2.4,
                  color: IConstructPanel.darkBlue,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget backOnly(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Align(
        alignment: Alignment.centerLeft,
        child: _BackButton(onTap: () => Navigator.pop(context)),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  final VoidCallback onTap;

  const _BackButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: IConstructPanel.darkBlue,
      shape: const CircleBorder(),
      elevation: 2,
      shadowColor: Colors.black26,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: const SizedBox(
          width: 44,
          height: 44,
          child: Icon(
            Icons.arrow_back_ios_new,
            color: Colors.white,
            size: 20,
          ),
        ),
      ),
    );
  }
}

/// Rebuilds when the IME height changes, and reports the larger of
/// [MediaQuery.viewInsets] and the raw Flutter [View] inset.
class _KeyboardInsetBuilder extends StatefulWidget {
  final Widget Function(BuildContext context, double keyboardInset) builder;

  const _KeyboardInsetBuilder({required this.builder});

  @override
  State<_KeyboardInsetBuilder> createState() => _KeyboardInsetBuilderState();
}

class _KeyboardInsetBuilderState extends State<_KeyboardInsetBuilder>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    if (mounted) setState(() {});
  }

  static double _insetOf(BuildContext context) {
    final fromMedia = MediaQuery.viewInsetsOf(context).bottom;
    final view = View.of(context);
    final fromView = view.viewInsets.bottom / view.devicePixelRatio;
    return fromMedia > fromView ? fromMedia : fromView;
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, _insetOf(context));
  }
}
