import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconstruct/core/theme/app_theme.dart';

enum AppMessageKind { warning, success, info }

/// Pins a snack message to the top-center of the visible screen (above the
/// keyboard and the pill nav), then shows it.
///
/// Failures default to a **warning** treatment (amber, not red error).
void showAppMessage(
  BuildContext context,
  SnackBar snackBar, {
  AppMessageKind? kind,
  Duration? duration,
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;

  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    _topCenterSnackBar(
      context,
      snackBar,
      kind: kind ?? _inferKind(snackBar),
      duration: duration,
    ),
  );
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
        Icon(style.icon, color: style.foreground, size: 22),
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
    required this.border,
    required this.icon,
  });

  final Color background;
  final Color foreground;
  final Color border;
  final IconData icon;
}

_MessageStyle _styleFor(AppMessageKind kind) {
  switch (kind) {
    case AppMessageKind.success:
      return const _MessageStyle(
        background: Color(0xFFE8F5E9),
        foreground: AppColors.success,
        border: Color(0xFF81C784),
        icon: Icons.check_circle_rounded,
      );
    case AppMessageKind.info:
      return const _MessageStyle(
        background: AppColors.navy,
        foreground: AppColors.creamLight,
        border: AppColors.steel,
        icon: Icons.info_outline_rounded,
      );
    case AppMessageKind.warning:
      return const _MessageStyle(
        background: Color(0xFFFFF4D6),
        foreground: AppColors.warning,
        border: Color(0xFFE0A84A),
        icon: Icons.warning_amber_rounded,
      );
  }
}

/// Amber helper text + icon used under auth fields instead of a red error.
Widget? warningFieldError(String? message) {
  if (message == null || message.isEmpty) return null;
  return Padding(
    padding: const EdgeInsets.only(top: 6),
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
              color: AppColors.warning,
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
