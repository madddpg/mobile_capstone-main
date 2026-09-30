import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:iconstruct/core/theme/app_theme.dart';

/// Copy for a confirmation shown before an action that throws away some of
/// the builder's estimate.
///
/// [message] says in plain words what will be lost or changed; [keeps], when
/// given, says what is safe, so the builder is not left guessing.
class LeaveWarning {
  final String title;
  final String message;
  final String? keeps;
  final String confirmLabel;
  final String cancelLabel;

  const LeaveWarning({
    required this.title,
    required this.message,
    this.keeps,
    this.confirmLabel = 'Leave anyway',
    this.cancelLabel = 'Stay',
  });

  /// Leaving the estimate flow entirely, e.g. from the bottom navigation.
  const LeaveWarning.exitEstimate({
    String? keeps,
    String message =
        'This estimate has not been saved yet. If you leave now, the choices, '
        'measurements and material list you have made so far will be '
        'cleared.',
  }) : this(
         title: 'Leave this estimate?',
         message: message,
         keeps: keeps,
         confirmLabel: 'Leave estimate',
         cancelLabel: 'Keep planning',
       );
}

/// Shows [warning] and resolves to true when the builder chose to go ahead.
Future<bool> confirmLeaveWarning(
  BuildContext context,
  LeaveWarning warning,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => LeaveWarningDialog(warning: warning),
  );
  return confirmed ?? false;
}

class LeaveWarningDialog extends StatelessWidget {
  final LeaveWarning warning;

  const LeaveWarningDialog({super.key, required this.warning});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: const Icon(
        Icons.info_outline_rounded,
        color: AppColors.warning,
        size: 30,
      ),
      title: Text(
        warning.title,
        textAlign: TextAlign.center,
        style: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.navy,
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              warning.message,
              style: GoogleFonts.poppins(
                fontSize: 13,
                height: 1.45,
                color: AppColors.textDark,
              ),
            ),
            if (warning.keeps != null) ...[
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 1),
                    child: Icon(
                      Icons.check_circle_outline_rounded,
                      size: 16,
                      color: AppColors.success,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      warning.keeps!,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        height: 1.4,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: [
        TextButton(
          key: const ValueKey('leave-warning-cancel'),
          onPressed: () => Navigator.pop(context, false),
          child: Text(
            warning.cancelLabel,
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
        ),
        TextButton(
          key: const ValueKey('leave-warning-confirm'),
          onPressed: () => Navigator.pop(context, true),
          style: TextButton.styleFrom(foregroundColor: AppColors.danger),
          child: Text(
            warning.confirmLabel,
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

/// Asks before a back step or a jump out of the estimate throws work away.
///
/// [onBack] covers leaving this screen for the one before it: the header
/// back button, Android system back and the iOS edge swipe all go through
/// it. [onExit] covers leaving the estimate flow altogether, as the bottom
/// navigation does; the topmost mounted guard answers for the whole flow, so
/// a screen pushed over it (e.g. Profile) still asks before a tab jump.
///
/// Both are read when the builder acts rather than when the screen builds, so
/// a text field that never calls setState is still seen as edited. Return
/// null when there is nothing to lose.
class ProgressGuard extends StatefulWidget {
  final LeaveWarning? Function()? onBack;
  final LeaveWarning? Function()? onExit;
  final Widget child;

  const ProgressGuard({
    super.key,
    this.onBack,
    this.onExit,
    required this.child,
  });

  static final List<_ProgressGuardState> _mounted = [];

  /// Asks the topmost guard whether leaving the estimate flow loses work, and
  /// if it does, confirms with the builder. True when it is fine to leave.
  static Future<bool> confirmExit(BuildContext context) async {
    if (_mounted.isEmpty) return true;
    final warning = _mounted.last.widget.onExit?.call();
    if (warning == null) return true;
    return confirmLeaveWarning(context, warning);
  }

  @override
  State<ProgressGuard> createState() => _ProgressGuardState();
}

class _ProgressGuardState extends State<ProgressGuard> {
  bool _confirming = false;

  @override
  void initState() {
    super.initState();
    ProgressGuard._mounted.add(this);
  }

  @override
  void dispose() {
    ProgressGuard._mounted.remove(this);
    super.dispose();
  }

  Future<void> _handlePop(bool didPop, Object? result) async {
    if (didPop || _confirming) return;
    final navigator = Navigator.of(context);
    final warning = widget.onBack?.call();
    if (warning != null) {
      _confirming = true;
      final leave = await confirmLeaveWarning(context, warning);
      _confirming = false;
      if (!leave || !mounted) return;
    }
    navigator.pop(result);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: widget.onBack == null,
      onPopInvokedWithResult: _handlePop,
      child: widget.child,
    );
  }
}
