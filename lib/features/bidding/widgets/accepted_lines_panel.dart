import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:iconstruct/core/firebase/firestore_error.dart';
import 'package:iconstruct/core/theme/app_theme.dart';
import 'package:iconstruct/core/widgets/app_message.dart';
import 'package:iconstruct/features/bidding/data/bid_comparison.dart';
import 'package:iconstruct/features/bidding/data/partial_acceptance.dart';
import 'package:iconstruct/features/bidding/data/remainder_canvass.dart';
import 'package:iconstruct/features/bidding/screens/posted_project_details_screen.dart';

/// What the builder took from a partly accepted quotation, and a way to
/// canvass what they left.
///
/// Before this, the card went on showing the shop's full quoted total, and
/// nothing anywhere said which lines had been kept, so the agreement was only
/// visible inside the sheet that made it.
class AcceptedLinesPanel extends StatelessWidget {
  final AcceptanceSummary summary;
  final double quotedTotal;
  final String postId;
  final String quotationId;
  final String shopName;

  /// Post id of the estimate already re-canvassing the dropped lines, if any.
  final String? remainderPostId;

  const AcceptedLinesPanel({
    super.key,
    required this.summary,
    required this.quotedTotal,
    required this.postId,
    required this.quotationId,
    required this.shopName,
    this.remainderPostId,
  });

  @override
  Widget build(BuildContext context) {
    final dropped = summary.dropped.length;
    final hasRemainder = (remainderPostId ?? '').isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.navy.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'You took ${summary.kept.length} of ${summary.totalCount} lines',
            style: GoogleFonts.poppins(
              color: AppColors.textDark,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            quotedTotal > 0
                ? '${formatBidMoney(summary.keptTotal)} of ${formatBidMoney(quotedTotal)} quoted'
                : formatBidMoney(summary.keptTotal),
            style: GoogleFonts.poppins(
              color: AppColors.textMuted,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 10),
          _LineGroup(
            label: 'Taken',
            lines: summary.kept,
            color: AppColors.success,
          ),
          const SizedBox(height: 8),
          _LineGroup(
            label: 'Not taken',
            lines: summary.dropped,
            color: AppColors.textMuted,
          ),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: double.infinity,
              minHeight: 44,
            ),
            child: OutlinedButton(
              onPressed: hasRemainder
                  ? () => _openEstimate(context, remainderPostId!)
                  : () => canvassDroppedLines(
                        context,
                        postId: postId,
                        quotationId: quotationId,
                        shopName: shopName,
                        droppedCount: dropped,
                      ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.navySoft,
                side: const BorderSide(color: AppColors.navySoft),
                shape: const StadiumBorder(),
              ),
              child: Text(
                hasRemainder
                    ? 'View the re-canvass'
                    : dropped == 1
                        ? 'Canvass the line you did not take'
                        : 'Canvass the $dropped lines you did not take',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LineGroup extends StatelessWidget {
  final String label;
  final List<Map<String, dynamic>> lines;
  final Color color;

  const _LineGroup({
    required this.label,
    required this.lines,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final names = [
      for (final line in lines)
        quotedItemName(line).isEmpty ? 'Unnamed item' : quotedItemName(line),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            color: color,
            fontWeight: FontWeight.w700,
            fontSize: 11.5,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          names.isEmpty ? 'None' : names.join(', '),
          style: GoogleFonts.poppins(
            color: AppColors.textDark,
            fontSize: 12,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}

void _openEstimate(BuildContext context, String postId) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => PostedProjectDetailsScreen(postId: postId),
    ),
  );
}

/// Confirms, then posts the dropped lines as a new estimate and opens it.
Future<void> canvassDroppedLines(
  BuildContext context, {
  required String postId,
  required String quotationId,
  required String shopName,
  required int droppedCount,
}) async {
  final lineWord = droppedCount == 1 ? 'line' : '$droppedCount lines';
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Canvass what you did not take?'),
      content: Text(
        'This posts a new estimate with only the $lineWord you did not take '
        'from $shopName, and asks hardware shops to quote them. Your order '
        'with $shopName stays as it is.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Post estimate'),
        ),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(
      child: CircularProgressIndicator(color: AppColors.cream),
    ),
  );

  try {
    final newPostId = await RemainderCanvassService().postDroppedLines(
      postId: postId,
      quotationId: quotationId,
    );
    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    showAppMessage(
      context,
      const SnackBar(
        content: Text('Sent to hardware shops. Waiting for quotations.'),
      ),
      kind: AppMessageKind.success,
    );
    _openEstimate(context, newPostId);
  } catch (error) {
    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    final message = error is FirebaseException
        ? firestoreUserMessage(error, action: 'post the remaining lines')
        : error.toString().replaceFirst(RegExp(r'^Exception: '), '');
    showAppMessage(
      context,
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }
}
