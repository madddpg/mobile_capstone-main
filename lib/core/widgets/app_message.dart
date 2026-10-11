import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconstruct/core/theme/app_theme.dart';

enum AppMessageKind { warning, success, info }

/// Shows [snackBar]'s message pinned to the top of the screen, above
/// everything else: open sheets and dialogs, the keyboard and the pill nav.
///
/// Inside the app this goes through [AppMessageHost]. A SnackBar belongs to
/// the page under any open sheet or dialog, so a message raised from one was
/// drawn behind it: dimmed by its scrim, or hidden outright ("Order line
/// copied" under the material sheet). Anywhere without a host, such as a
/// widget test that pumps a bare MaterialApp, it falls back to a SnackBar.
///
/// Failures default to a **warning** treatment (amber, not red error).
void showAppMessage(
  BuildContext context,
  SnackBar snackBar, {
  AppMessageKind? kind,
  Duration? duration,
}) {
  final resolvedKind = kind ?? _inferKind(snackBar);
  final host = context.findAncestorStateOfType<_AppMessageHostState>();
  if (host != null && host.mounted) {
    host.show(
      snackBar.content,
      kind: resolvedKind,
      duration: duration ?? snackBar.duration,
    );
    return;
  }

  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;

  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    _topCenterSnackBar(
      context,
      snackBar,
      kind: resolvedKind,
      duration: duration,
    ),
  );
}

/// The layer app messages are drawn on, above the navigator and so above
/// every page, sheet and dialog. Wraps the navigator in MaterialApp.builder.
///
/// A message sits under the status bar and grows with its text: the
/// SnackBar it replaces assumed a 96-pixel bar, so a three-line message ran
/// up under the status bar. The keyboard cannot cover it, and screen readers
/// announce it.
class AppMessageHost extends StatefulWidget {
  const AppMessageHost({super.key, required this.child});

  final Widget child;

  @override
  State<AppMessageHost> createState() => _AppMessageHostState();
}

class _AppMessageHostState extends State<AppMessageHost>
    with SingleTickerProviderStateMixin {
  // Made in initState, not lazily: a host that never showed a message would
  // otherwise first create it in dispose(), where a ticker cannot be made.
  late final AnimationController _motion;

  @override
  void initState() {
    super.initState();
    _motion = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      reverseDuration: const Duration(milliseconds: 160),
    );
  }

  _HostedMessage? _message;
  Timer? _timer;
  int _serial = 0;

  void show(
    Widget content, {
    required AppMessageKind kind,
    required Duration duration,
  }) {
    _timer?.cancel();
    setState(() {
      _message = _HostedMessage(
        serial: ++_serial,
        content: content,
        kind: kind,
      );
    });
    _motion.forward(from: 0);
    // With a screen reader on, the message is read out first, so it stays
    // longer.
    final accessible = MediaQuery.maybeAccessibleNavigationOf(context) ?? false;
    _timer = Timer(accessible ? duration * 2 : duration, _hide);
  }

  Future<void> _hide() async {
    _timer?.cancel();
    final shown = _message;
    if (shown == null) return;
    await _motion.reverse();
    if (mounted && _message?.serial == shown.serial) {
      setState(() => _message = null);
    }
  }

  void _dismissed() {
    _timer?.cancel();
    setState(() => _message = null);
    _motion.value = 0;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final message = _message;
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (message != null)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, -1.3),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(
                    parent: _motion,
                    curve: Curves.easeOutCubic,
                    reverseCurve: Curves.easeInCubic,
                  )),
                  child: FadeTransition(
                    opacity: _motion,
                    child: Dismissible(
                      key: ValueKey(message.serial),
                      direction: DismissDirection.up,
                      onDismissed: (_) => _dismissed(),
                      child: GestureDetector(
                        onTap: _hide,
                        child: AppMessageCard(
                          kind: message.kind,
                          child: message.content,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _HostedMessage {
  const _HostedMessage({
    required this.serial,
    required this.content,
    required this.kind,
  });

  final int serial;
  final Widget content;
  final AppMessageKind kind;
}

/// One message as the builder sees it: icon, text, and the colours of its
/// kind. Text colours meet the 4.5:1 contrast that body text needs.
class AppMessageCard extends StatelessWidget {
  const AppMessageCard({super.key, required this.kind, required this.child});

  final AppMessageKind kind;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final style = _styleFor(kind);
    return Semantics(
      container: true,
      liveRegion: true,
      child: Material(
        color: style.background,
        elevation: 8,
        shadowColor: Colors.black54,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: style.border, width: 1.2),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(style.icon, color: style.iconColor, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: DefaultTextStyle.merge(
                  textAlign: TextAlign.left,
                  style: GoogleFonts.poppins(
                    color: style.foreground,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                  child: child,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

AppMessageKind _inferKind(SnackBar source) {
  final bg = source.backgroundColor;
  if (bg == null) return AppMessageKind.warning;
  // Greens used for success snacks in this app (e.g. Colors.green.shade400).
  if (bg.g > bg.r + 0.12 && bg.g > bg.b + 0.12) {
    return AppMessageKind.success;
  }
  return AppMessageKind.warning;
}

SnackBar _topCenterSnackBar(
  BuildContext context,
  SnackBar source, {
  required AppMessageKind kind,
  Duration? duration,
}) {
  final media = MediaQuery.of(context);
  final topInset = media.padding.top + 12;
  const barHeight = 96.0;
  final visibleHeight = media.size.height - media.viewInsets.bottom;
  final bottomGap =
      (visibleHeight - topInset - barHeight).clamp(16.0, 4000.0);

  final style = _styleFor(kind);

  return SnackBar(
    content: Row(
      children: [
        Icon(style.icon, color: style.iconColor, size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: DefaultTextStyle.merge(
            textAlign: TextAlign.left,
            style: GoogleFonts.poppins(
              color: style.foreground,
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
            child: source.content,
          ),
        ),
      ],
    ),
    backgroundColor: style.background,
    elevation: 8,
    padding: source.padding ??
        const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    duration: duration ?? source.duration,
    action: source.action,
    showCloseIcon: source.showCloseIcon,
    closeIconColor: style.foreground,
    onVisible: source.onVisible,
    behavior: SnackBarBehavior.floating,
    dismissDirection: DismissDirection.up,
    margin: EdgeInsets.fromLTRB(20, 0, 20, bottomGap),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: BorderSide(color: style.border, width: 1.2),
    ),
  );
}

class _MessageStyle {
  const _MessageStyle({
    required this.background,
    required this.foreground,
    required this.iconColor,
    required this.border,
    required this.icon,
  });

  final Color background;

  /// The text. At least 4.5:1 against [background].
  final Color foreground;

  /// The icon, which as a symbol needs 3:1.
  final Color iconColor;
  final Color border;
  final IconData icon;
}

/// Text darker than [AppColors.warning]: that amber reads at 3.9:1 on the
/// warning's pale background, under the 4.5:1 body text needs.
const Color _warningText = Color(0xFF8A5200); // 5.9:1 on 0xFFFFF4D6
const Color _successText = Color(0xFF256B29); // 5.7:1 on 0xFFE8F5E9

_MessageStyle _styleFor(AppMessageKind kind) {
  switch (kind) {
    case AppMessageKind.success:
      return const _MessageStyle(
        background: Color(0xFFE8F5E9),
        foreground: _successText,
        iconColor: AppColors.success,
        border: Color(0xFF81C784),
        icon: Icons.check_circle_rounded,
      );
    case AppMessageKind.info:
      return const _MessageStyle(
        background: AppColors.navy,
        foreground: AppColors.creamLight,
        iconColor: AppColors.creamLight,
        border: AppColors.steel,
        icon: Icons.info_outline_rounded,
      );
    case AppMessageKind.warning:
      return const _MessageStyle(
        background: Color(0xFFFFF4D6),
        foreground: _warningText,
        iconColor: AppColors.warning,
        border: Color(0xFFE0A84A),
        icon: Icons.warning_amber_rounded,
      );
  }
}

/// Amber helper text + icon used under auth fields instead of a red error.
Widget? warningFieldError(String? message) {
  if (message == null || message.isEmpty) return null;
  // On its own pale amber background. Amber text straight on the sign-in
  // screens' navy measured 1.9:1 to 2.1:1 on a phone, too faint to read;
  // this reads at 5.9:1 on any screen behind it.
  return Container(
    margin: const EdgeInsets.only(top: 6),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF4D6),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFFE0A84A)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.warning_amber_rounded,
          size: 16,
          color: AppColors.warning,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            message,
            style: GoogleFonts.poppins(
              color: _warningText,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
        ),
      ],
    ),
  );
}

OutlineInputBorder warningErrorBorder({double width = 1.2}) {
  return OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: AppColors.warning, width: width),
  );
}
