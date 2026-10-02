import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:iconstruct/core/theme/app_theme.dart';

/// Shared primary and secondary actions.
///
/// One height, radius, padding, and label treatment everywhere a screen
/// asks the builder to continue, sign in, or register. Width follows the
/// parent when [expand] is true, and the label wraps instead of clipping.
class AppButtons {
  const AppButtons._();

  static const double minHeight = 48;
  static const double radius = 14;
  static const EdgeInsets padding = EdgeInsets.symmetric(
    horizontal: 16,
    vertical: 12,
  );

  static TextStyle labelStyle({Color? color}) => GoogleFonts.poppins(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: color,
  );

  static Widget label(String text) {
    return Text(
      text,
      textAlign: TextAlign.center,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  static Widget spinner({Color color = AppColors.creamLight}) {
    return SizedBox(
      height: 20,
      width: 20,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        valueColor: AlwaysStoppedAnimation<Color>(color),
      ),
    );
  }
}

class AppPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  /// Stretches to the width of the parent. Screens that already use a
  /// full-width action pass true (the default).
  final bool expand;

  const AppPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.expand = true,
  });

  @override
  Widget build(BuildContext context) {
    final button = ElevatedButton(
      onPressed: loading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.navy,
        foregroundColor: AppColors.creamLight,
        disabledBackgroundColor: AppColors.navy.withValues(alpha: 0.45),
        disabledForegroundColor: AppColors.creamLight,
        elevation: 0,
        minimumSize: Size(expand ? 64 : 64, AppButtons.minHeight),
        padding: AppButtons.padding,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppButtons.radius),
        ),
        textStyle: AppButtons.labelStyle(),
      ),
      child: loading ? AppButtons.spinner() : AppButtons.label(label),
    );

    if (!expand) return button;
    return SizedBox(width: double.infinity, child: button);
  }
}

class AppSecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final bool expand;

  const AppSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.expand = true,
  });

  @override
  Widget build(BuildContext context) {
    final button = OutlinedButton(
      onPressed: loading ? null : onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.navy,
        disabledForegroundColor: AppColors.navy.withValues(alpha: 0.45),
        backgroundColor: AppColors.creamLight.withValues(alpha: 0.55),
        minimumSize: const Size(64, AppButtons.minHeight),
        padding: AppButtons.padding,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        side: const BorderSide(color: AppColors.navy, width: 1.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppButtons.radius),
        ),
        textStyle: AppButtons.labelStyle(color: AppColors.navy),
      ),
      child: loading
          ? AppButtons.spinner(color: AppColors.navy)
          : AppButtons.label(label),
    );

    if (!expand) return button;
    return SizedBox(width: double.infinity, child: button);
  }
}
