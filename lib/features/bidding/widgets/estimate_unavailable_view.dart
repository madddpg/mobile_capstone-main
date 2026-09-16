import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconstruct/core/theme/app_theme.dart';
import 'package:iconstruct/core/widgets/app_message.dart';
import 'package:iconstruct/core/widgets/iconstruct_panel.dart';
import 'package:iconstruct/features/bidding/data/post_load_outcome.dart';
import 'package:iconstruct/features/project_creation/data/project_status_service.dart';

/// Shown in place of an estimate that could not be opened.
///
/// Says which of the failures happened, because each has a different way out:
/// an offline read is worth retrying, while a post that is gone or no longer
/// readable will fail the same way every time, so the builder is offered the
/// chance to unlink it from their saved project and post again.
class EstimateUnavailableView extends StatefulWidget {
  final PostLoadOutcome outcome;
  final String postId;
  final VoidCallback onRetry;

  /// For screens without their own header, so the builder is not left with
  /// only the system back gesture.
  final bool showBackButton;

  const EstimateUnavailableView({
    super.key,
    required this.outcome,
    required this.postId,
    required this.onRetry,
    this.showBackButton = false,
  });

  @override
  State<EstimateUnavailableView> createState() =>
      _EstimateUnavailableViewState();
}

class _EstimateUnavailableViewState extends State<EstimateUnavailableView> {
  bool _unlinking = false;

  Future<void> _unlink() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || _unlinking) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unlink this estimate?'),
        content: const Text(
          'Your saved project keeps its materials and goes back to ready to '
          'post. Quotations on the old post will no longer show in the app.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Unlink'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _unlinking = true);
    try {
      final count = await ProjectStatusService.instance.unlinkPost(
        userId: uid,
        postId: widget.postId,
      );
      if (!mounted) return;
      showAppMessage(
        context,
        SnackBar(
          content: Text(
            count == 0
                ? 'None of your saved projects point at this estimate any more.'
                : 'Unlinked. Open the project in Saved Projects to post it again.',
          ),
        ),
        kind: count == 0 ? AppMessageKind.info : AppMessageKind.success,
      );
      Navigator.pop(context);
    } catch (_) {
      if (!mounted) return;
      setState(() => _unlinking = false);
      showAppMessage(
        context,
        const SnackBar(
          content: Text(
            'That did not unlink. Check your connection and try again.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final copy = switch (widget.outcome) {
      PostLoadOutcome.offline => (
          icon: Icons.wifi_off_rounded,
          title: "You're offline",
          body: 'This estimate needs a connection to load its quotations. '
              'Reconnect, then try again.',
        ),
      PostLoadOutcome.unavailable => (
          icon: Icons.link_off_rounded,
          title: 'This estimate is no longer available',
          body: 'It may have been removed, or it can no longer be opened from '
              'your account, so its quotations cannot be shown. Unlink it and '
              'your saved project goes back to ready to post, with its '
              'materials kept.',
        ),
      PostLoadOutcome.failed || PostLoadOutcome.loaded => (
          icon: Icons.error_outline_rounded,
          title: "This estimate didn't load",
          body: 'Something went wrong while opening it. Try again in a moment.',
        ),
    };

    final isUnavailable = widget.outcome == PostLoadOutcome.unavailable;

    // Centered when it fits, scrollable when it does not: the unavailable copy
    // runs taller than a small phone once the text is enlarged.
    final content = LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    copy.icon,
                    size: 44,
                    color: AppColors.cream.withValues(alpha: 0.8),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    copy.title,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      color: AppColors.cream,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    copy.body,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      color: AppColors.cream.withValues(alpha: 0.8),
                      fontSize: 14,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isUnavailable
                          ? (_unlinking ? null : _unlink)
                          : widget.onRetry,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.cream,
                        foregroundColor: IConstructPanel.navy,
                        disabledBackgroundColor:
                            AppColors.cream.withValues(alpha: 0.4),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                      ),
                      child: _unlinking
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              isUnavailable
                                  ? 'Unlink from my project'
                                  : 'Try again',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                  if (isUnavailable) ...[
                    const SizedBox(height: 6),
                    TextButton(
                      onPressed:
                          _unlinking ? null : () => Navigator.pop(context),
                      child: Text(
                        'Go back',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: AppColors.cream,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (!widget.showBackButton) return content;

    return Stack(
      children: [
        content,
        Positioned(
          top: 10,
          left: 12,
          child: IconButton(
            tooltip: 'Back',
            onPressed: () => Navigator.pop(context),
            icon: const Icon(
              Icons.arrow_back_ios_new,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
      ],
    );
  }
}
